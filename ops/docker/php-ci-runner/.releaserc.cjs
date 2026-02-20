const base = require('../../../.releaserc.js');

module.exports = {
  ...base,
  tagFormat: 'php-ci-runner-v${version}',
};
