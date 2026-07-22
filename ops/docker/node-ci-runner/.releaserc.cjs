const base = require('../../../.releaserc.js');

module.exports = {
  ...base,
  tagFormat: 'node-ci-runner-v${version}',
};
