-- Seed the AEO weekly-tracking registry with the first two clients.
-- Values are lifted verbatim from their vertical_insights CI configs
-- (reports/ci_pipeline/config/{dibara_vs_alphastructural,bawtry_vs_paintballgames}.yaml)
-- so the tracked prompts / competitors / regexes match what we already validated.
--
-- Idempotent: ON CONFLICT re-applies. Uses jsonb_build_* so the competitor
-- regexes keep their single backslashes (no JSON-escaping foot-guns).
-- Requires 002_aeo_schema.sql first.

INSERT INTO aeo.client
    (client_id, name, domain, aliases, subject_pattern, vertical, country, engines,
     competitors, prompts, cadence, active, notes)
VALUES (
    'dibara_masonry',
    'DiBara Masonry',
    'dibaramasonry.com',
    ARRAY['DiBara Masonry','DiBara','Di Bara Masonry','Matthew DiBara'],
    'di\s?bara',
    'masonry',
    'US',
    ARRAY['chatgpt','perplexity','google_ai'],
    jsonb_build_array(
        jsonb_build_object('name','Alpha Structural','pattern','alpha\s?structural','domain','alphastructural.com'),
        jsonb_build_object('name','Julian Construction','pattern','julian\s+construction','domain',''),
        jsonb_build_object('name','Dalinghaus Construction','pattern','dalinghaus','domain',''),
        jsonb_build_object('name','Foundation Repair LA','pattern','foundation\s+repair\s+l\.?a\.?','domain',''),
        jsonb_build_object('name','Bellwether Masonry','pattern','bellwether','domain',''),
        jsonb_build_object('name','SoCal Masonry','pattern','socal\s+masonry','domain',''),
        jsonb_build_object('name','Angi','pattern','angi\b','domain',''),
        jsonb_build_object('name','Yelp','pattern','yelp','domain',''),
        jsonb_build_object('name','Thumbtack','pattern','thumbtack','domain','')
    ),
    jsonb_build_array(
        jsonb_build_object('text','Best masonry contractor in Los Angeles','branded',false),
        jsonb_build_object('text','Who should I hire to build a retaining wall in Los Angeles','branded',false),
        jsonb_build_object('text','Best retaining wall contractor in Los Angeles hillside property','branded',false),
        jsonb_build_object('text','Best hardscape and paver contractor in Glendale California','branded',false),
        jsonb_build_object('text','Who repairs brick and stone walls in Los Angeles','branded',false),
        jsonb_build_object('text','Best foundation and structural repair contractor in Los Angeles','branded',false),
        jsonb_build_object('text','DiBara Masonry reviews','branded',true),
        jsonb_build_object('text','DiBara Masonry vs Alpha Structural','branded',true)
    ),
    'weekly',
    true,
    'LA masonry/hardscape/retaining walls. Google Ads registered under owner name "Matthew DiBara", not the domain.'
)
ON CONFLICT (client_id) DO UPDATE SET
    name=EXCLUDED.name, domain=EXCLUDED.domain, aliases=EXCLUDED.aliases,
    subject_pattern=EXCLUDED.subject_pattern, vertical=EXCLUDED.vertical, country=EXCLUDED.country,
    engines=EXCLUDED.engines, competitors=EXCLUDED.competitors, prompts=EXCLUDED.prompts,
    cadence=EXCLUDED.cadence, active=EXCLUDED.active, notes=EXCLUDED.notes, updated_at=now();

INSERT INTO aeo.client
    (client_id, name, domain, aliases, subject_pattern, vertical, country, engines,
     competitors, prompts, cadence, active, notes)
VALUES (
    'bawtry_paintball',
    'Bawtry Paintball & Laser Fields',
    'bawtrypaintballfields.co.uk',
    ARRAY['Bawtry Paintball','Bawtry Paintball Fields','Bawtry Paintball & Laser Fields','Bawtry Paintball and Laser Fields'],
    'bawtry',
    'paintball',
    'GB',
    ARRAY['chatgpt','perplexity','google_ai'],
    jsonb_build_array(
        jsonb_build_object('name','Delta Force','pattern','delta\s?force|paintballgames','domain','paintballgames.co.uk'),
        jsonb_build_object('name','UK Paintball','pattern','ukpaintball|uk paintball','domain','ukpaintball.co.uk'),
        jsonb_build_object('name','GO Paintball','pattern','go paintball','domain',''),
        jsonb_build_object('name','Skirmish','pattern','skirmish','domain',''),
        jsonb_build_object('name','NPF','pattern','\bnpf\b|national paintball','domain',''),
        jsonb_build_object('name','Ambush','pattern','ambush paintball','domain',''),
        jsonb_build_object('name','Campaign Paintball','pattern','campaign paintball','domain','')
    ),
    jsonb_build_array(
        jsonb_build_object('text','Best paintball near Doncaster','branded',false),
        jsonb_build_object('text','Best paintball in South Yorkshire','branded',false),
        jsonb_build_object('text','Paintball near Sheffield','branded',false),
        jsonb_build_object('text','Kids paintball party Doncaster','branded',false),
        jsonb_build_object('text','Stag do paintball Yorkshire','branded',false),
        jsonb_build_object('text','Best activity centre near Doncaster for kids','branded',false),
        jsonb_build_object('text','Laser tag near Doncaster','branded',false),
        jsonb_build_object('text','Best paintball in the UK','branded',false),
        jsonb_build_object('text','Bawtry Paintball reviews','branded',true),
        jsonb_build_object('text','Delta Force Paintball reviews','branded',true)
    ),
    'weekly',
    true,
    'Single multi-activity centre, Bawtry Forest, Doncaster. Competitor Delta Force = national chain (paintballgames.co.uk). Google Ads under parent "Extreme Corporate Events Ltd".'
)
ON CONFLICT (client_id) DO UPDATE SET
    name=EXCLUDED.name, domain=EXCLUDED.domain, aliases=EXCLUDED.aliases,
    subject_pattern=EXCLUDED.subject_pattern, vertical=EXCLUDED.vertical, country=EXCLUDED.country,
    engines=EXCLUDED.engines, competitors=EXCLUDED.competitors, prompts=EXCLUDED.prompts,
    cadence=EXCLUDED.cadence, active=EXCLUDED.active, notes=EXCLUDED.notes, updated_at=now();
