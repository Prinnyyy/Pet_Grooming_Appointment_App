<!-- task-artifact
task: T-433
status: completed
type: plan
-->

# Handoff 4 P5 — messages

Reads: section 3 item 9; D8; appendix A P5. D-069 adopts the new UI/UX and continuous execution.

Adopt the shared booking ticket and unavailable strip, both role styles and groomer list wiring. Preserve production ⚑ ChatView navigation/cache/Updating/no thread skeleton. Validate the affected message flow, then continue P6.

## Section 10 report

Completed.

Port map: `Features/Chat/ChatBookingCard.swift` from `PrototypeChatBookingCard.swift` (two runtime cards only); ⚑ `ChatView.swift` replaces its private legacy card and both role call sites/styles, preserves typed customer destinations and the groomer NavigationLink, and uses the prototype's unavailable strip text. The shell already supplies coral plus the shared customer-language Messages layout. No fixture or preview dependency enters runtime. Both roles see one full-width ticket rather than a person-aligned bubble; no card entrance added.

D-069/D8: production T-426/427 cached messages, Updating header, no thread skeleton, session/read/send guards and composer were retained. D1/D2/D3/D4/D5/D6/D7/D9/D10 unchanged; D2 deployment is P7, D10 is P6. No new backend operation. Tests reused the affected real Store/reliability suites; no redundant screenshot tests were added for this presentation-only card change.

Validation: Debug Simulator build and **47/47** chat Store/reliability tests passed, zero skips. The first test invocation stopped before testing on a build-database lock; after confirming no builder remained the second invocation passed. Node boundary/source/audit **29/29**, preflight, UI audit, hygiene and whitespace passed. One resolved old baseline entry pruned. Evidence `/tmp/beckon-handoff4/p5-*`. Release generic Simulator build passed. User owns visual inspection; final integrated semantic taps remain P8.
