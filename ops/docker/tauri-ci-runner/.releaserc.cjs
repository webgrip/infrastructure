const base = require('../../../.releaserc.js');

module.exports = {
  ...base,
  tagFormat: 'tauri-ci-runner-v${version}',
};

// re-cut marker (2026-07-23): a push must touch this dir to enter the changed-images release
// matrix — this line re-entered the image after its release was dropped (see fix(release) commit).
