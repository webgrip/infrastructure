const base = require('../../../.releaserc.js');

module.exports = {
  ...base,
  tagFormat: 'tauri-ci-runner-v${version}',
};
