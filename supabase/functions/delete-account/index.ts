import { withSupabase } from "npm:@supabase/server";
import { handleDeleteAccount } from "./delete-account.mjs";

export default {
  fetch: withSupabase({ auth: "user" }, async (request, ctx) =>
    handleDeleteAccount({
      request,
      userClient: ctx.supabase,
      adminClient: ctx.supabaseAdmin,
    })
  ),
};
