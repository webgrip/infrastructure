const base = require('../../../.releaserc.js');

module.exports = {
  ...base,
  tagFormat: 'rust-releaser-v${version}',
};
