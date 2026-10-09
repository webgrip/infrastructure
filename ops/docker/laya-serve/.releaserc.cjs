'use strict';

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
