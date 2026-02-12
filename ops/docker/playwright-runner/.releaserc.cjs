const base = require('../../../.releaserc.js');

module.exports = {
  ...base,
  tagFormat: 'playwright-runner-v${version}',
};
