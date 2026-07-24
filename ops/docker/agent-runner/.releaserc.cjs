'use strict';

// Docker-image release train for this package dir. monorepo mode scopes commit analysis to this
// dir and derives the tag prefix (<image>-v*) from the sibling package.json name. manifest: 'npm'
// commits the bumped package.json back; dockerVerifyGate() proves the image still builds BEFORE
// the tag is cut (reading the buildx cache the publish path writes, via BUILD_CACHE_REF exported
// by the composite). Legacy feature/bugfix/hotfix commit types are kept alive via extra* until
// commitlint retires them. All plugin shape lives in @webgrip/semantic-release-config.
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
