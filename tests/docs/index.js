(async () => {
  await import("./context-hygiene-check.test.mjs");
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
