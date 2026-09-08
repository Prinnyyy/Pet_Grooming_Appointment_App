import { randomUUID } from "node:crypto";

function saveParameters(schedule, timeOff) {
  return { p_expected_revision: schedule.revision, p_windows: schedule.windows,
    p_preferences: schedule.preferences, p_time_off: timeOff };
}

export async function runTimingAdmissionRace(api, { offerID, serviceStart, groomerID, customerToken, groomerToken, databaseBarrier }) {
  const schedule = await api.rpc("get_groomer_availability", {}, groomerToken);
  if (schedule?.timing_version !== 1 || typeof schedule.revision !== "string"
    || !Array.isArray(schedule.time_off) || !Array.isArray(schedule.windows) || schedule.windows.length !== 7) {
    throw new Error("Timing race requires a confirmed versioned schedule.");
  }
  const zone = schedule.windows[0].timezone;
  if (schedule.windows.some(window => window.timezone !== zone)) throw new Error("Timing race requires one schedule time zone.");
  const parts = new Intl.DateTimeFormat("en", { timeZone: zone, year: "numeric", month: "2-digit", day: "2-digit" })
    .formatToParts(new Date(serviceStart));
  const component = type => parts.find(part => part.type === type).value;
  const day = `${component("year")}-${component("month")}-${component("day")}`;
  const dateLabel = value => {
    const values = new Intl.DateTimeFormat("en", { timeZone: zone, year: "numeric", month: "2-digit", day: "2-digit" })
      .formatToParts(new Date(value));
    return ["year", "month", "day"].map(type => values.find(part => part.type === type).value).join("-");
  };
  // An existing appointment on this day would make the Save lose regardless of the race.
  let offset = 0;
  while (true) {
    const bookings = await api.restSelect("bookings",
      `select=id,scheduled_start,scheduled_end,occupied_start,occupied_end&groomer_id=eq.${groomerID}&status=in.(confirmed,completed)&order=id.asc&limit=200&offset=${offset}`, groomerToken);
    if (!Array.isArray(bookings)) throw new Error("Cannot verify an isolated race day.");
    if (bookings.some(booking => dateLabel(booking.occupied_start ?? booking.scheduled_start) <= day
      && dateLabel(booking.occupied_end ?? booking.scheduled_end) >= day)) {
      throw new Error("Timing race requires a day without existing booking occupancy.");
    }
    if (bookings.length === 0) break;
    offset += bookings.length;
    if (offset >= 10000) throw new Error("Timing race fixture exceeds bounded occupancy inspection.");
  }
  const timeOffID = randomUUID();
  const timeOff = { id: timeOffID, title: "T-374 admission race", start_date: day, end_date: day };
  let result;
  let failure;
  try {
    const dispatch = () => Promise.allSettled([
      api.rpc("accept_groomer_offer", { p_offer_id: offerID }, customerToken),
      api.rpc("save_groomer_availability", saveParameters(schedule, [...schedule.time_off, timeOff]), groomerToken),
    ]);
    const [acceptance, save] = await (databaseBarrier ? databaseBarrier(groomerID, dispatch) : dispatch());
    if (acceptance.status === save.status) {
      throw new Error("Timing race requires exactly one successful operation.");
    }
    const bookingWon = acceptance.status === "fulfilled";
    const rejected = bookingWon ? save.reason : acceptance.reason;
    const expectedMessage = bookingWon ? "time_off_conflicts_with_booking_occupancy" : "occupied_time_off_conflict";
    if (rejected?.code !== "22023" || rejected?.serverMessage !== expectedMessage) {
      throw new Error("Timing race lost through an unexpected error, not the expected occupancy conflict.");
    }
    const bookings = await api.restSelect("bookings", `select=id,offer_id,status&offer_id=eq.${offerID}`, customerToken);
    const bookingID = bookingWon ? acceptance.value?.[0]?.booking_id : null;
    if (bookingWon ? (!bookingID || bookings.length !== 1 || bookings[0].id !== bookingID
      || bookings[0].offer_id !== offerID || bookings[0].status !== "confirmed") : bookings.length !== 0) {
      throw new Error("Timing race booking readback disagrees with the RPC outcome.");
    }
    const current = await api.rpc("get_groomer_availability", {}, groomerToken);
    if (current.time_off.some(row => row.id === timeOffID) === bookingWon) {
      throw new Error("Timing race time-off readback disagrees with the RPC outcome.");
    }
    result = { winner: bookingWon ? "booking" : "time_off", bookingID,
      dispatch: databaseBarrier ? "verified-database-lock-contention" : "concurrent-http",
      bookingReadbackVerified: true, timeOffReadbackVerified: true };
  } catch (error) { failure = error; }
  try {
    const current = await api.rpc("get_groomer_availability", {}, groomerToken);
    if (!Array.isArray(current?.time_off)) throw new Error("Cannot verify temporary time-off restoration.");
    if (current.time_off.some(row => row.id === timeOffID)) {
      await api.rpc("save_groomer_availability",
        saveParameters(current, current.time_off.filter(row => row.id !== timeOffID)), groomerToken);
      const restored = await api.rpc("get_groomer_availability", {}, groomerToken);
      if (!Array.isArray(restored?.time_off) || restored.time_off.some(row => row.id === timeOffID)) {
        throw new Error("Temporary race time off remains after restoration.");
      }
    }
  } catch (error) {
    if (failure) throw new AggregateError([failure, error], "Timing race and temporary time-off restoration failed.");
    throw error;
  }
  if (failure) throw failure;
  return result;
}
