# T-129 Customer Test Profiles

Status: imported to Supabase remote project `lqmasbuqzvcvtawonjlb` on 2026-07-01 by T-135.

Purpose: seed a realistic customer population for pet-profile, coat-type, request publishing, request matching, booking, and chat QA. Each customer has exactly two pets: one dog and one cat.

## Address Source and Safety

- All profile addresses are real, public institution addresses in Los Angeles County or Orange County.
- The address pool is drawn from official public library / municipal facility listings: `https://lacountylibrary.org/locations/`, `https://www.ocpl.org/libraries`, and `https://www.orangepubliclibrary.org/visit/facilities`.
- These addresses are for geocoding and matching tests only. They do not claim that a seeded groomer, customer, pet, or business occupies the public facility.
- Do not replace these with private residential addresses or real pet-business addresses unless the owner has explicitly authorized test use.

## Shared Import Rules

- Auth role: `customer`.
- Password for every account: `GroomlyTest!2026`.
- Email domain: `example.com`, reserved for test documentation and not intended for real inbox use.
- Create the Supabase Auth user first, then call the app onboarding/profile path for role `customer`, then update `profiles`, `customer_profiles`, and owned `pets`.
- `Seed ID` is a local external key only. Do not use it as a Supabase UUID.
- Customer avatars and pet avatar photos are intentionally omitted. Add optional images later through `customer-avatars` and `pet-photos` if image testing is needed.
- Pet fields use current app vocabulary:
  - species: `Dog` or `Cat`
  - breed: fixed title from `CustomerPetBreed`, including `Unspecified` and `Mixed Breed`
  - coat type: raw `CustomerPetCoatType` value
  - temperament: fixed `CustomerPetTemperament` title
  - size is derived by backend/app from `weight_lbs`

## Remote Import Notes

- T-135 created or updated these 50 customer Auth users through the Supabase Admin API, confirmed email login, and wrote the public profile/customer-profile/pet rows through service-role REST.
- Reusable script: `scripts/seed-t129-customers.mjs`.
- Default script mode is dry-run:
  `node scripts/seed-t129-customers.mjs`
- Remote write mode requires service-role credentials in environment variables:
  `SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... node scripts/seed-t129-customers.mjs --execute`
- The script is idempotent for these emails. It updates existing matching Auth users, replaces owned pet rows for the seed customers, and refuses to overwrite a public profile whose role is not `customer`.
- Cleanup should use the explicit `groomly.customerNNN@example.com` email prefix and/or Auth `app_metadata.groomly_seed = T-129`; do not delete unrelated users by broad domain alone.
- The GTC-019 Great Dane fixture uses `101 lb` because the deployed app contract limits `pets.weight_lbs` to 5...101.

## Profiles

| Seed ID | Email | Password | Nickname / Contact | Address | Dog Pet | Cat Pet |
|---|---|---|---|---|---|---|
| GTC-001 | groomly.customer001@example.com | GroomlyTest!2026 | Amelia / amelia.customer001@example.com / 310-555-1001 | 3965 Cesar E Chavez Ave, Los Angeles, CA 90063 | Mochi; Toy Poodle; curly_wavy; 9 lb; 2022-04-11; Friendly; notes: teddy trim, mats behind ears | Juniper; Domestic Shorthair; short_smooth; 10 lb; 2020-08-03; Calm; notes: nail trim only |
| GTC-002 | groomly.customer002@example.com | GroomlyTest!2026 | Marcus / marcus.customer002@example.com / 323-555-1002 | 17906 S Avalon Blvd, Carson, CA 90746 | Bear; Golden Retriever; double_coat; 72 lb; 2018-06-18; Social; notes: heavy shed, sensitive hips | Cleo; Siamese; short_smooth; 8 lb; 2021-02-14; Independent; notes: low tolerance for dryer |
| GTC-003 | groomly.customer003@example.com | GroomlyTest!2026 | Priya / priya.customer003@example.com / 562-555-1003 | 11949 Alondra Blvd, Norwalk, CA 90650 | Pepper; Miniature Schnauzer; wire; 17 lb; 2019-09-22; Protective; notes: beard trim, may bark at clippers | Olive; Domestic Longhair; long_silky; 12 lb; 2017-12-09; Gentle; notes: sanitary trim, tangles under chest |
| GTC-004 | groomly.customer004@example.com | GroomlyTest!2026 | Nora / nora.customer004@example.com / 626-555-1004 | 6518 Miles Ave, Huntington Park, CA 90255 | Lulu; Shih Tzu; drop_coat; 14 lb; 2023-01-20; Playful; notes: first full groom, face trim | Milo; Maine Coon; long_silky; 16 lb; 2019-04-30; Calm; notes: brush-out and nail trim |
| GTC-005 | groomly.customer005@example.com | GroomlyTest!2026 | Zoe / zoe.customer005@example.com / 818-555-1005 | 4990 Clark Ave, Lakewood, CA 90712 | Biscuit; French Bulldog; short_smooth; 24 lb; 2021-07-08; Anxious; notes: short bath, avoid overheating | Pearl; Persian; long_silky; 9 lb; 2018-11-17; Shy; notes: tear stain cleanup |
| GTC-006 | groomly.customer006@example.com | GroomlyTest!2026 | Leah / leah.customer006@example.com / 213-555-1006 | 4264 E Whittier Blvd, Los Angeles, CA 90023 | Maple; Labrador Retriever; double_coat; 65 lb; 2020-03-05; Friendly; notes: de-shed, ear cleaning | Nova; Bengal; short_smooth; 11 lb; 2022-05-23; Energetic; notes: quick nail trim |
| GTC-007 | groomly.customer007@example.com | GroomlyTest!2026 | Jonah / jonah.customer007@example.com / 424-555-1007 | 1900 E Firestone Blvd, Los Angeles, CA 90001 | Waffles; Bichon Frise; curly_wavy; 15 lb; 2021-10-02; Playful; notes: round head, frequent matting | Hazel; Ragdoll; long_silky; 13 lb; 2020-01-12; Affectionate; notes: brush belly carefully |
| GTC-008 | groomly.customer008@example.com | GroomlyTest!2026 | Hannah / hannah.customer008@example.com / 310-555-1008 | 14433 Crenshaw Blvd, Gardena, CA 90249 | Tank; Pit Bull; short_smooth; 58 lb; 2017-08-27; Reactive; notes: muzzle trained, nail grinding | Luna; Russian Blue; short_smooth; 9 lb; 2019-07-19; Nervous; notes: quiet room preferred |
| GTC-009 | groomly.customer009@example.com | GroomlyTest!2026 | Ethan / ethan.customer009@example.com / 323-555-1009 | 3854 W 54th St, Los Angeles, CA 90043 | Nori; Yorkshire Terrier; drop_coat; 7 lb; 2020-12-02; Gentle; notes: top knot, fine coat tangles | Theo; British Shorthair; short_smooth; 14 lb; 2018-02-26; Independent; notes: nail trim |
| GTC-010 | groomly.customer010@example.com | GroomlyTest!2026 | Mia / mia.customer010@example.com / 562-555-1010 | 4533 Admiralty Way, Marina del Rey, CA 90292 | Kona; Siberian Husky; double_coat; 55 lb; 2019-05-15; Energetic; notes: coat blowout, no shaving | Misty; Domestic Shorthair; short_smooth; 10 lb; 2021-09-08; Social; notes: brush and nails |
| GTC-011 | groomly.customer011@example.com | GroomlyTest!2026 | Sophie / sophie.customer011@example.com / 626-555-1011 | 24200 Narbonne Ave, Lomita, CA 90717 | Archie; Poodle; curly_wavy; 22 lb; 2022-02-10; Friendly; notes: lamb cut, mat check | Poppy; Scottish Fold; short_smooth; 8 lb; 2020-06-21; Calm; notes: gentle ear handling |
| GTC-012 | groomly.customer012@example.com | GroomlyTest!2026 | Oliver / oliver.customer012@example.com / 818-555-1012 | 1320 Highland Ave, Manhattan Beach, CA 90266 | Angus; Mixed Breed; wire; 31 lb; 2018-09-03; Protective; notes: wire coat, hand-strip consult | Iris; Domestic Longhair; long_silky; 12 lb; 2017-10-12; Shy; notes: mats near tail |
| GTC-013 | groomly.customer013@example.com | GroomlyTest!2026 | Clara / clara.customer013@example.com / 213-555-1013 | 4323 E Slauson Ave, Maywood, CA 90270 | Daisy; Beagle; short_smooth; 26 lb; 2023-03-14; Playful; notes: first groom, treat-motivated | Suki; Siamese; short_smooth; 7 lb; 2022-07-07; Nervous; notes: short session |
| GTC-014 | groomly.customer014@example.com | GroomlyTest!2026 | Daniel / daniel.customer014@example.com / 424-555-1014 | 122 N Topanga Canyon Blvd, Topanga, CA 90290 | Scout; Australian Shepherd; double_coat; 48 lb; 2020-11-30; Energetic; notes: sanitary trim, de-shed | Mochi Cat; Persian; long_silky; 10 lb; 2018-04-18; Gentle; notes: comb-out |
| GTC-015 | groomly.customer015@example.com | GroomlyTest!2026 | Isabella / isabella.customer015@example.com / 310-555-1015 | 21155 La Puente Rd, Walnut, CA 91789 | Tofu; Maltese; drop_coat; 8 lb; 2021-01-25; Anxious; notes: short face trim | Bean; Sphynx; hairless_low_coat; 8 lb; 2020-03-03; Affectionate; notes: skin wipe and nails |
| GTC-016 | groomly.customer016@example.com | GroomlyTest!2026 | Noah / noah.customer016@example.com / 323-555-1016 | 208 N Harvard Ave, Claremont, CA 91711 | Ruby; German Shepherd; double_coat; 76 lb; 2018-05-29; Protective; notes: de-shed, reactive to dryer | Juno; Maine Coon; long_silky; 18 lb; 2019-12-13; Calm; notes: large cat, brush-out |
| GTC-017 | groomly.customer017@example.com | GroomlyTest!2026 | Emma / emma.customer017@example.com / 562-555-1017 | 20540 E Arrow Highway Suite K, Covina, CA 91724 | Coco; Standard Poodle; curly_wavy; 52 lb; 2020-07-17; Social; notes: full haircut, clean feet | Tilly; Domestic Shorthair; short_smooth; 9 lb; 2022-01-09; Playful; notes: nail trim |
| GTC-018 | groomly.customer018@example.com | GroomlyTest!2026 | Lucas / lucas.customer018@example.com / 626-555-1018 | 1060 S Greenwood Ave, Montebello, CA 90640 | Pickles; Cavalier King Charles Spaniel; long_silky; 18 lb; 2019-08-01; Gentle; notes: feather trim | Maple Cat; Ragdoll; long_silky; 13 lb; 2021-04-04; Affectionate; notes: brush-out |
| GTC-019 | groomly.customer019@example.com | GroomlyTest!2026 | Olivia / olivia.customer019@example.com / 818-555-1019 | 4420 E Rose St, East Rancho Dominguez, CA 90221 | Moose; Great Dane; short_smooth; 101 lb; 2017-06-06; Calm; notes: giant bath, senior joints | Kiwi; Bengal; short_smooth; 11 lb; 2020-02-22; Energetic; notes: quick nails |
| GTC-020 | groomly.customer020@example.com | GroomlyTest!2026 | Henry / henry.customer020@example.com / 213-555-1020 | 4035 Tweedy Blvd, South Gate, CA 90280 | Ziggy; Chihuahua; short_smooth; 6 lb; 2022-11-11; Nervous; notes: small-dog handling | Olive Cat; British Shorthair; short_smooth; 13 lb; 2018-09-16; Independent; notes: nail trim |
| GTC-021 | groomly.customer021@example.com | GroomlyTest!2026 | Harper / harper.customer021@example.com / 424-555-1021 | 14615 Burin Ave, Lawndale, CA 90260 | Rumi; Toy Poodle; curly_wavy; 8 lb; 2021-03-12; Friendly; notes: teddy face | Cleo Cat; Persian; long_silky; 9 lb; 2019-10-20; Shy; notes: mat prevention |
| GTC-022 | groomly.customer022@example.com | GroomlyTest!2026 | Jack / jack.customer022@example.com / 310-555-1022 | 601 W Lancaster Blvd, Lancaster, CA 93534 | Honey; Cocker Spaniel; long_silky; 28 lb; 2018-08-08; Gentle; notes: ear care, feather trim | Blue; Russian Blue; short_smooth; 10 lb; 2020-12-24; Calm; notes: brush and nails |
| GTC-023 | groomly.customer023@example.com | GroomlyTest!2026 | Amelia W / ameliaw.customer023@example.com / 323-555-1023 | 4545 N Oakwood Ave, La Canada Flintridge, CA 91011 | Clover; Corgi; double_coat; 27 lb; 2022-06-02; Playful; notes: de-shed and paw trim | Miso; Siamese; short_smooth; 8 lb; 2021-05-05; Social; notes: nails |
| GTC-024 | groomly.customer024@example.com | GroomlyTest!2026 | Benjamin / benjamin.customer024@example.com / 562-555-1024 | 2809 Foothill Blvd, La Crescenta, CA 91214 | Bruno; Bulldog; short_smooth; 44 lb; 2019-02-14; Calm; notes: skin folds, no heat | Nala; Domestic Longhair; long_silky; 12 lb; 2017-07-30; Shy; notes: knots behind legs |
| GTC-025 | groomly.customer025@example.com | GroomlyTest!2026 | Chloe / chloe.customer025@example.com / 626-555-1025 | 16010 La Monde St, Hacienda Heights, CA 91745 | Finn; Mixed Breed; wire; 19 lb; 2020-05-25; Reactive; notes: Westie terrier mix, wire coat, terrier trim | Saffron; Scottish Fold; short_smooth; 9 lb; 2022-03-17; Gentle; notes: ear-sensitive |
| GTC-026 | groomly.customer026@example.com | GroomlyTest!2026 | Mason / mason.customer026@example.com / 818-555-1026 | 18801 Elaine Avenue, Artesia, CA 90701 | Sunny; Golden Retriever; double_coat; 68 lb; 2019-09-09; Friendly; notes: de-shed, trim feathers | Pippa; Maine Coon; long_silky; 17 lb; 2018-06-12; Calm; notes: big cat brush-out |
| GTC-027 | groomly.customer027@example.com | GroomlyTest!2026 | Ella / ella.customer027@example.com / 213-555-1027 | 9945 E Flower St, Bellflower, CA 90706 | Gigi; Boston Terrier; short_smooth; 18 lb; 2023-04-19; Playful; notes: first bath and nails | Rosie; Domestic Shorthair; short_smooth; 8 lb; 2021-11-02; Playful; notes: nail trim |
| GTC-028 | groomly.customer028@example.com | GroomlyTest!2026 | Aria / aria.customer028@example.com / 424-555-1028 | 4181 Baldwin Park Blvd, Baldwin Park, CA 91706 | Baxter; Miniature Schnauzer; wire; 16 lb; 2018-01-28; Protective; notes: schnauzer pattern | Willow; Domestic Longhair; long_silky; 11 lb; 2020-08-18; Nervous; notes: quiet handling |
| GTC-029 | groomly.customer029@example.com | GroomlyTest!2026 | Logan / logan.customer029@example.com / 310-555-1029 | 4357 E Gage Ave, Bell, CA 90201 | Aspen; Border Collie; double_coat; 42 lb; 2020-10-07; Energetic; notes: de-shed, paw trim | Sage; Bengal; short_smooth; 12 lb; 2022-09-09; Energetic; notes: fast nail trim |
| GTC-030 | groomly.customer030@example.com | GroomlyTest!2026 | Victoria / victoria.customer030@example.com / 323-555-1030 | 7110 S Garfield Ave, Bell Gardens, CA 90201 | Otis; Dachshund; short_smooth; 21 lb; 2014-12-12; Calm; notes: senior back care | Lola; Ragdoll; long_silky; 14 lb; 2016-05-30; Affectionate; notes: gentle brush |
| GTC-031 | groomly.customer031@example.com | GroomlyTest!2026 | Owen / owen.customer031@example.com / 562-555-1031 | 5218 Santa Ana St, Cudahy, CA 90201 | Poppy Dog; Bichon Frise; curly_wavy; 14 lb; 2022-02-28; Playful; notes: round face, mats easily | Marble; British Shorthair; short_smooth; 13 lb; 2019-01-19; Independent; notes: nail trim |
| GTC-032 | groomly.customer032@example.com | GroomlyTest!2026 | Riley / riley.customer032@example.com / 626-555-1032 | 21800 Copley Dr, Diamond Bar, CA 91765 | Ranger; Rottweiler; double_coat; 92 lb; 2018-07-04; Protective; notes: big dog, de-shed | Ginger; Persian; long_silky; 10 lb; 2017-03-15; Shy; notes: comb-out |
| GTC-033 | groomly.customer033@example.com | GroomlyTest!2026 | Stella / stella.customer033@example.com / 818-555-1033 | 1301 Buena Vista St, Duarte, CA 91010 | Millie; Maltese; drop_coat; 7 lb; 2020-04-22; Anxious; notes: quiet handling | Ash; Russian Blue; short_smooth; 9 lb; 2021-06-06; Calm; notes: brush and nails |
| GTC-034 | groomly.customer034@example.com | GroomlyTest!2026 | Julian / julian.customer034@example.com / 213-555-1034 | 3224 Tyler Ave, El Monte, CA 91731 | Echo; Shiba Inu; double_coat; 24 lb; 2019-11-29; Independent; notes: hates dryer, heavy shed | Dot; Domestic Shorthair; short_smooth; 8 lb; 2022-02-02; Social; notes: nail trim |
| GTC-035 | groomly.customer035@example.com | GroomlyTest!2026 | Penelope / penelope.customer035@example.com / 424-555-1035 | 11940 Carson St, Hawaiian Gardens, CA 90716 | Fifi; Yorkshire Terrier; drop_coat; 6 lb; 2021-12-01; Gentle; notes: fine coat, top knot | Coco Cat; Siamese; short_smooth; 8 lb; 2019-08-08; Nervous; notes: short appointment |
| GTC-036 | groomly.customer036@example.com | GroomlyTest!2026 | Wyatt / wyatt.customer036@example.com / 562-555-1036 | 1501 E. St. Andrew Place, Santa Ana, CA 92705 | Buddy; Labrador Retriever; double_coat; 74 lb; 2018-02-01; Friendly; notes: bath and de-shed | Snow; Ragdoll; long_silky; 13 lb; 2020-10-10; Affectionate; notes: brush belly |
| GTC-037 | groomly.customer037@example.com | GroomlyTest!2026 | Layla / layla.customer037@example.com / 714-555-1037 | 7531 E. Santiago Canyon Road, Silverado, CA 92676 | Rocky; Boxer; short_smooth; 63 lb; 2017-09-18; Reactive; notes: nail grind, no other dogs | Jade; Bengal; short_smooth; 10 lb; 2021-03-03; Energetic; notes: nails only |
| GTC-038 | groomly.customer038@example.com | GroomlyTest!2026 | Sofia / sofia.customer038@example.com / 949-555-1038 | 12700 Montecito, Seal Beach, CA 90740 | Archie F; Miniature Schnauzer; wire; 18 lb; 2020-01-14; Protective; notes: hand strip consult | Winnie; Domestic Longhair; long_silky; 12 lb; 2018-08-28; Shy; notes: mat removal |
| GTC-039 | groomly.customer039@example.com | GroomlyTest!2026 | Carter / carter.customer039@example.com / 657-555-1039 | 30902 La Promesa, Rancho Santa Margarita, CA 92688 | Noodle; Mixed Breed; curly_wavy; 23 lb; 2023-05-15; Playful; notes: unknown doodle mix, first haircut | Pepper Cat; Scottish Fold; short_smooth; 9 lb; 2020-02-20; Gentle; notes: ear-sensitive |
| GTC-040 | groomly.customer040@example.com | GroomlyTest!2026 | Natalie / natalie.customer040@example.com / 562-555-1040 | 242 Avenida Del Mar, San Clemente, CA 92672 | Gracie; Cocker Spaniel; long_silky; 31 lb; 2014-04-04; Gentle; notes: senior, ear cleaning | Bluebell; Domestic Shorthair; short_smooth; 11 lb; 2016-09-09; Calm; notes: nails |
| GTC-041 | groomly.customer041@example.com | GroomlyTest!2026 | Leo / leo.customer041@example.com / 714-555-1041 | 31495 El Camino Real, San Juan Capistrano, CA 92675 | Benny; Poodle; curly_wavy; 18 lb; 2021-06-16; Friendly; notes: full groom, clean face | Kiki; Persian; long_silky; 9 lb; 2018-12-12; Shy; notes: comb-out |
| GTC-042 | groomly.customer042@example.com | GroomlyTest!2026 | Audrey / audrey.customer042@example.com / 949-555-1042 | 707 Electric Avenue, Seal Beach, CA 90740 | June; German Shepherd; double_coat; 70 lb; 2019-03-03; Protective; notes: de-shed, low dryer | Fig; Russian Blue; short_smooth; 8 lb; 2021-01-31; Independent; notes: nail trim |
| GTC-043 | groomly.customer043@example.com | GroomlyTest!2026 | Savannah / savannah.customer043@example.com / 657-555-1043 | 7850 Katella Avenue, Stanton, CA 90680 | Olive Dog; Shih Tzu; drop_coat; 13 lb; 2020-07-22; Anxious; notes: face trim, mats around legs | Jasper; Maine Coon; long_silky; 17 lb; 2017-11-11; Calm; notes: brush-out |
| GTC-044 | groomly.customer044@example.com | GroomlyTest!2026 | Eli / eli.customer044@example.com / 562-555-1044 | 345 E. Main Street, Tustin, CA 92780 | Peanut; Beagle; short_smooth; 29 lb; 2023-02-02; Energetic; notes: first nail trim | Mabel; Domestic Shorthair; short_smooth; 10 lb; 2020-05-05; Social; notes: nails and brush |
| GTC-045 | groomly.customer045@example.com | GroomlyTest!2026 | Maya / maya.customer045@example.com / 714-555-1045 | 17865 Santiago Blvd., Villa Park, CA 92861 | Scout MV; Mixed Breed; wire; 20 lb; 2018-10-10; Reactive; notes: Westie terrier mix, patient handling | Lyra; Siamese; short_smooth; 7 lb; 2022-06-18; Nervous; notes: short session |
| GTC-046 | groomly.customer046@example.com | GroomlyTest!2026 | Caleb / caleb.customer046@example.com / 949-555-1046 | 8180 13th Street, Westminster, CA 92683 | Daisy Sac; Golden Retriever; double_coat; 69 lb; 2018-08-14; Friendly; notes: de-shed, feather trim | Pumpkin; Ragdoll; long_silky; 13 lb; 2020-09-19; Affectionate; notes: brush-out |
| GTC-047 | groomly.customer047@example.com | GroomlyTest!2026 | Emilia / emilia.customer047@example.com / 657-555-1047 | 407 E. Chapman Ave, Orange, CA 92866 | Diesel; Doberman Pinscher; short_smooth; 82 lb; 2019-12-01; Protective; notes: nails and bath | Echo Cat; Bengal; short_smooth; 11 lb; 2021-05-12; Energetic; notes: quick nails |
| GTC-048 | groomly.customer048@example.com | GroomlyTest!2026 | Ava / ava.customer048@example.com / 562-555-1048 | 380 S. Hewes St, Orange, CA 92869 | Rosie Dog; Cavalier King Charles Spaniel; long_silky; 17 lb; 2014-07-07; Gentle; notes: senior gentle groom | Sage Cat; Domestic Longhair; long_silky; 12 lb; 2016-03-03; Shy; notes: mats under tail |
| GTC-049 | groomly.customer049@example.com | GroomlyTest!2026 | Mateo / mateo.customer049@example.com / 714-555-1049 | 740 E. Taft Ave, Orange, CA 92865 | Theo Dog; Standard Poodle; curly_wavy; 54 lb; 2020-02-20; Social; notes: full haircut, mat prevention | Pearl Cat; Persian; long_silky; 9 lb; 2018-05-05; Gentle; notes: tear stain cleanup |
| GTC-050 | groomly.customer050@example.com | GroomlyTest!2026 | Grace / grace.customer050@example.com / 949-555-1050 | 1855 Park Avenue, Costa Mesa, CA 92627 | Luna Dog; Siberian Husky; double_coat; 51 lb; 2022-01-01; Energetic; notes: blowout, no shave | Opal; Sphynx; hairless_low_coat; 8 lb; 2021-07-07; Affectionate; notes: skin wipe and nails |

## Import Checklist

Before inserting these records remotely:

1. Confirm whether email confirmation should be bypassed through an admin seed path.
2. Confirm whether the seed should create only accounts/profile/pets or also publish initial grooming requests.
3. Keep each customer pet owned by the matching seeded customer user ID.
4. Do not store pet avatar photos unless the image seed scope is separately approved.
5. Build a reversible cleanup path by email prefix and/or an explicit seed marker.
