const base = require('../../../.releaserc.js');

module.exports = {
  ...base,
  tagFormat: 'techdocs-runner-v${version}',
};
