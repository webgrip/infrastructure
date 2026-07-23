const base = require('../../../.releaserc.js');

module.exports = {
  ...base,
  tagFormat: 'rust-ci-runner-v${version}',
};

// re-cut marker (2026-07-23): a push must touch this dir to enter the changed-images release
// matrix — this line re-entered the image after its release was dropped (see fix(release) commit).
// re-entered again 2026-07-24: run 125 lost this release to a docker.io TLS flake booting buildkit.
