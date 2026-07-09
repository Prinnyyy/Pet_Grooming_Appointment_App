(async () => {
  await import("./context-hygiene-check.test.mjs");
  await import("./context-rotate.test.mjs");
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
