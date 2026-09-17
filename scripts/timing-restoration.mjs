import { isDeepStrictEqual } from "node:util";

export async function runWithTimingRestoration({ snapshot, run, cleanup }) {
  const before = await snapshot();
  const errors = [];
  let result;
  let cleanupResult;
  try { result = await run(); }
  catch (error) { errors.push(error); }
  try {
    cleanupResult = await cleanup();
    if (cleanupResult?.remainingTaggedRequests !== 0) {
      throw new Error("Tagged cleanup did not confirm zero remaining requests.");
    }
  } catch (error) { errors.push(error); }
  try {
    const after = await snapshot();
    if (!isDeepStrictEqual(after, before)) {
      throw new Error("Timing fixture changed after cleanup; exact restoration is unverified.");
    }
  } catch (error) { errors.push(error); }
  if (errors.length === 1) throw errors[0];
  if (errors.length > 1) {
    throw new AggregateError(errors, "Timing acceptance failed; inspect operation and restoration evidence before another run.");
  }
  return { ...result, cleanup: cleanupResult, restoration: { verified: true } };
}
