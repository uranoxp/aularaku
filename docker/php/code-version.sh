#!/bin/sh
set -eu

php -r '
require "/var/www/moodle/version.php";
echo "branch=" . $branch . PHP_EOL;
echo "release=" . $release . PHP_EOL;
'
