-- T-098 Fix profile avatar_path extension regex.
-- Authorized target: lqmasbuqzvcvtawonjlb only.
--
-- T-004 used a doubly escaped regex in profiles_avatar_path_check. The rest of
-- the path validation is correct, but legal owner paths like
-- {user_id}/{file_id}.jpg fail the extension check, causing avatar uploads to
-- succeed in Storage and then roll back when profiles.avatar_path cannot update.

alter table public.profiles
drop constraint profiles_avatar_path_check;

alter table public.profiles
add constraint profiles_avatar_path_check check (
  avatar_path is null
  or (
    char_length(avatar_path) <= 512
    and split_part(avatar_path, '/', 1) = id::text
    and split_part(avatar_path, '/', 2) <> ''
    and array_length(string_to_array(avatar_path, '/'), 1) = 2
    and lower(avatar_path) ~ '\.(jpe?g|png|heic|heif)$'
  )
);

comment on constraint profiles_avatar_path_check on public.profiles is
  'Ensures private avatar_path stays under the owning user folder and uses an allowed image extension.';
