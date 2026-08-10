#!/usr/bin/env bash

# Enable imaginary server preview generation on the differential-test pair
# (SUT `nextcloud` + pure-PHP oracle). The OCC config:system:set calls write
# to each container's config/config.php, so both instances get the identical
# provider set + preview_imaginary_url — a precondition for the phase-16
# differential harness (both sides must generate through the same Imaginary).
#
# Re-run after `docker compose down -v` (config.php is wiped with the config
# volume): docker compose up nextcloud oracle previews_hpb, then this script.

set -e
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
# shellcheck source=example.env
source "${SCRIPT_DIR}/../.env"
# shellcheck source=scripts/functions.sh
source "${SCRIPT_DIR}/functions.sh"

function OCC () {
    local container="$1"
    shift
    docker_compose exec "$container" sudo -E -u www-data "./occ" "$@"
}

for container in nextcloud oracle; do
    echo "=> Configuring ${container} …"
    # The app's info.xml <background-jobs> (the PreviewJob that drains
    # oc_preview_generation) is registered at app INSTALL.  A recreated DB
    # (docker compose down -v) whose appconfig was seeded without the install
    # flow loses the job, and the differential harness's quiescence then polls
    # a queue that never drains (~60 s per scenario).  Re-run the install flow
    # to re-register it (disable is a no-op error if the app isn't enabled).
    OCC "$container" app:disable previewgenerator || true
    OCC "$container" app:enable previewgenerator
    OCC "$container" config:system:set enabledPreviewProviders 0 --value 'OC\Preview\MP3'
    OCC "$container" config:system:set enabledPreviewProviders 1 --value 'OC\Preview\TXT'
    OCC "$container" config:system:set enabledPreviewProviders 2 --value 'OC\Preview\MarkDown'
    OCC "$container" config:system:set enabledPreviewProviders 3 --value 'OC\Preview\OpenDocument'
    OCC "$container" config:system:set enabledPreviewProviders 4 --value 'OC\Preview\Krita'
    OCC "$container" config:system:set enabledPreviewProviders 5 --value 'OC\Preview\Imaginary'
    OCC "$container" config:system:set preview_imaginary_url --value 'http://previews_hpb:8088'
done

# The SUT's Rust nc-server reads config.php once at startup — restart so it
# picks up preview_imaginary_url + the narrowed provider set.
echo "=> Restarting nextcloud + oracle …"
docker_compose restart nextcloud oracle
