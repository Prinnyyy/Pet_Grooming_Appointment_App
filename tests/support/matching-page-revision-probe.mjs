import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';

// Run the actual page SQL expressions against constants, without creating fixtures or functions.
export function buildPageRevisionProbe(sql) {
  const cacheExpressions = [...sql.matchAll(/to_jsonb\(c\)-(?:'witness'|array\[[^\]]+\])/g)].map(match => match[0]);
  assert.equal(cacheExpressions.length, 2, 'Both role branches must supply a cache projection');
  const source = sql.match(/source:=(jsonb_build_object\('facts'[\s\S]*?);\n    select extensions/);
  const pendingEvents = sql.match(/\(select jsonb_agg\(q.id order by q.id\)[\s\S]*?q.groomer_id=actor[^)]*\)/);
  const revision = sql.match(/select encode\(extensions.digest\(convert_to\(jsonb_build_object\('mode',effective,[\s\S]*?into revision from jsonb_array_elements\(ranked\);/);
  assert.ok(source && pendingEvents && revision, 'Page revision expressions must be identifiable');
  const eventRelation = "jsonb_to_recordset(inputs.events) as q(id bigint,request_id uuid,groomer_id uuid,reason text)";
  const sourceSQL = source[1].replace('app_private.match_refresh_queue q', eventRelation);
  const pendingSQL = pendingEvents[0].replace('app_private.match_refresh_queue q', eventRelation);
  const revisionSQL = revision[0].replace('into revision', 'as revision').replace(/;$/, '');
  const request = '00000000-0000-4000-8000-000000000001';
  const groomer = '00000000-0000-4000-8000-000000000002';
  const baseline = {
    effective: 'fit', enabled: true, assessment: 0, pending: false, events: [],
    cache: { request_id: request, groomer_id: groomer, result: { state: 'estimated_fit' }, witness: {},
      source_revision: 10, evidence_revision: 0, rating_revision: 0, display_revision: 0,
      ranking_revision: '00000000-0000-4000-8000-000000000003',
      evaluated_at: '2026-09-13T12:00:00Z', valid_until: '2026-09-13T12:30:00Z', next_evaluation_at: '2026-09-13T12:30:00Z' },
    rows: [{ item: 'match-1', candidate: request, group: 0, distance: 5, newest: -1, earliest: null, price: null,
      sort_key: [0, 0, -27, 'stable-tie', request, 'match-1'],
      score: { f: 57.56, b: 55.29, q: 57.56, s: 56.4 },
      payload: { request: { terms_revision: 'terms-1' }, match: { status: 'visible' },
        evidence: { state: 'available', coverage: [{ positive: 1, negative: 0 }] } } }],
  };
  const event = reason => ({ id: 21, request_id: request, groomer_id: groomer, reason });
  const cases = [];
  function add(name, same, change, prepare = () => {}) {
    const before = structuredClone(baseline); prepare(before);
    const after = structuredClone(before); change(after);
    cases.push({ name, same, before, after });
  }
  add('groomer-star-only', true, x => { x.rows[0].score.q = 42.44; x.rows[0].score.s = 52.62; });
  add('rating-event-enqueued', true, x => { x.events.push(event('rating')); });
  add('evidence-event-enqueued-without-visible-change', true, x => { x.events.push(event('evidence')); });
  add('display-event-enqueued-without-visible-change', true, x => { x.events.push(event('display')); });
  add('soft-worker-drained', true, x => {
    x.events = []; x.cache.rating_revision = 21; x.cache.evidence_revision = 22; x.cache.display_revision = 23;
    x.cache.ranking_revision = '00000000-0000-4000-8000-000000000004';
  }, x => { x.events.push(event('rating')); });
  add('coarse-pending-soft-event', true, x => { x.events.push(event('display')); }, x => { x.pending = true; });
  add('customer-visible-stars', false, x => { x.rows[0].payload.groomer_profile.rating_avg = 1; },
    x => { x.effective = 'balanced'; x.rows[0].payload.groomer_profile = { rating_avg: 5 }; });
  add('score-bucket-moved', false, x => { x.rows[0].sort_key[2] = -28; });
  add('professional-evidence-changed', false, x => { x.rows[0].payload.evidence.coverage[0].negative = 1; });
  add('hard-event-enqueued', false, x => { x.events.push(event('hard_eligibility')); });
  add('hard-worker-drained', false, x => { x.cache.source_revision = 21; });
  add('eligibility-revoked', false, x => { x.cache.result = { state: 'pending', reason: 'refresh_pending' }; });
  add('quote-no-longer-selectable', false, x => { x.rows[0].payload.quote_evaluation.selectable = false; },
    x => { x.rows[0].payload.quote_evaluation = { selectable: true }; });
  add('request-terms-changed', false, x => { x.rows[0].payload.request.terms_revision = 'terms-2'; });
  add('candidate-removed', false, x => { x.rows = []; });
  add('candidate-added', false, x => {
    const row = structuredClone(x.rows[0]); row.item = 'match-2'; row.sort_key[5] = row.item; x.rows.push(row);
  });
  add('fallback-mode-changed', false, x => { x.effective = 'time_fallback'; });
  add('rollout-disabled', false, x => { x.enabled = false; });
  add('assessment-count-changed', false, x => { x.assessment = 1; });
  add('pending-candidate-changed', false, x => { x.pending = true; });
  add('input-enumeration-order', true, x => { x.rows.reverse(); }, x => {
    const row = structuredClone(x.rows[0]); row.item = 'match-2'; row.sort_key[5] = row.item; x.rows.push(row);
  });
  const inputs = cases.flatMap(c => ['before', 'after'].map(side => ({
    name: c.name, side, expected_same: c.same, ...c[side],
  })));
  const literal = JSON.stringify(inputs).replaceAll("'", "''");
  return `with inputs as (
    select * from jsonb_to_recordset('${literal}'::jsonb) as i(name text,side text,expected_same boolean,
      effective text,enabled boolean,assessment integer,pending boolean,events jsonb,cache jsonb,rows jsonb)
  ), results as (
    select inputs.name,inputs.side,inputs.expected_same,branches.cache_branch,result.revision
    from inputs
    cross join lateral jsonb_populate_record(null::app_private.match_candidate_evaluations,inputs.cache) c
    cross join lateral (values ('groomer',${cacheExpressions[0]}),('customer',${cacheExpressions[1]})) branches(cache_branch,cache)
    cross join lateral (select c.request_id,c.groomer_id,branches.cache as source) fact
    cross join lateral (select c.result as evaluation,c.groomer_id as actor) context
    cross join lateral (select ${sourceSQL} as source) sources
    cross join lateral (select coalesce(jsonb_agg(value||jsonb_build_object('source',sources.source)),'[]') ranked
      from jsonb_array_elements(inputs.rows)) candidates
    cross join lateral (select case when inputs.pending then jsonb_build_array(jsonb_build_object(
      'request',c.request_id,'events',${pendingSQL})) else '[]'::jsonb end pending_sources) coarse
    cross join lateral (select inputs.enabled) config
    cross join lateral (${revisionSQL}) result
  ) select a.name,a.cache_branch,a.expected_same,(a.revision=b.revision) actual_same,
    ((a.revision=b.revision)=a.expected_same) passed
    from results a join results b on b.name=a.name and b.cache_branch=a.cache_branch and b.side='after'
    where a.side='before' order by a.name,a.cache_branch;`;
}

export function checkPageRevisionResults(rows) {
  assert.equal(rows.length, 42, 'All 21 cases must exercise both cache projections');
  assert.equal(new Set(rows.map(row => `${row.name}:${row.cache_branch}`)).size, 42, 'No duplicate results');
  for (const row of rows) {
    assert.equal(typeof row.actual_same, 'boolean');
    assert.equal(row.actual_same, row.expected_same, `${row.name}:${row.cache_branch}`);
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const { values } = parseArgs({ options: { source: { type: 'string' }, results: { type: 'string' } } });
  assert.ok(Boolean(values.source) !== Boolean(values.results), 'Specify --source SQL or --results JSON');
  if (values.source) process.stdout.write(buildPageRevisionProbe(readFileSync(values.source, 'utf8')) + '\n');
  else {
    checkPageRevisionResults(JSON.parse(readFileSync(values.results, 'utf8')));
    console.log('Page revision probe: 42 passed');
  }
}
