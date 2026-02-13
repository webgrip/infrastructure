const base = require('../../../.releaserc.js');

module.exports = {
  ...base,
  tagFormat: 'techdocs-builder-v${version}',
};
