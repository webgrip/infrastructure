const base = require('../../../.releaserc.js');

module.exports = {
  ...base,
  tagFormat: 'act-runner-v${version}',
};
