# Imaginary

Enable the imaginary server for generating previews

```bash
docker compose up proxy nextcloud oracle previews_hpb
./scripts/enable-preview-imaginary.sh
```

The script configures the differential-test pair (SUT `nextcloud` + pure-PHP
`oracle`) via `occ config:system:set` — identical `enabledPreviewProviders`
(Imaginary + non-image providers; the GD image providers are excluded so every
image preview goes through the same Imaginary backend) and
`preview_imaginary_url` — then restarts both so the SUT's Rust nc-server (which
reads config.php at startup) picks it up. Re-run after `docker compose down -v`
(the config volume is wiped).
