'use strict';

// Docker-image release train for this dir. monorepo mode scopes commit analysis here and derives
// the tag prefix (<image>-v*) from the sibling package.json name. manifest:'npm' commits the bumped
// package.json back; dockerVerifyGate() proves the image still builds before the tag is cut (reads
// the buildx cache the publish path writes, via BUILD_CACHE_REF exported by the composite). Legacy
// feature/bugfix/hotfix types kept alive until commitlint retires them. Shared factory:
const { makeConfig, dockerVerifyGate } = require('@webgrip/semantic-release-config');

module.exports = makeConfig({
  monorepo: true,
  manifest: 'npm',
  verifyReleaseCmd: dockerVerifyGate(),
  extraReleaseRules: [
    { type: 'feature', release: 'minor' },
    { type: 'bugfix', release: 'patch' },
    { type: 'hotfix', release: 'patch' },
  ],
  extraNotesTypes: [
    { type: 'feature', section: 'Added' },
    { type: 'bugfix', section: 'Fixed' },
    { type: 'hotfix', section: 'Fixed' },
  ],
});
