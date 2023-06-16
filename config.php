<?php

/*
 * Moodle configuration file
 */

unset($CFG);
global $CFG;
$CFG = new stdClass();

/*
 * Database configuration
 */

$CFG->dbtype = 'mysqli';
$CFG->dblibrary = 'native';
$CFG->dbhost = getenv('DB_HOST') ?: '127.0.0.1';
$CFG->dbname = getenv('DB_DATABASE') ?: 'moodle';
$CFG->dbuser = getenv('DB_USERNAME') ?: 'moodle';
$CFG->dbpass = getenv('DB_PASSWORD') ?: '';
$CFG->prefix = 'mdl_';
$CFG->dboptions = [
    'dbpersist' => 0,
    'dbport' => intval(getenv('DB_PORT') ?: 3306),
    'dbsocket' => getenv('DB_SOCKET') ?: '',
    'dbcollation' => 'utf8mb4_unicode_ci',
];

/*
 * Redis cache / session store configuration
 */

$redisHost = getenv('REDIS_HOST') ?: '127.0.0.1';
$redisPort = intval(getenv('REDIS_PORT') ?: 6379);
$redisPassword = getenv('REDIS_PASSWORD') ?: '';

$CFG->alternative_cache_factory_class = 'tool_forcedcache_cache_factory';
$CFG->tool_forcedcache_config_array = [
    'stores' => [
        'apcu' => [
            'type' => 'apcu',
            'config' => [
                'prefix' => 'apcu_',
            ],
        ],
        'redis' => [
            'type' => 'redis',
            'config' => [
                'server' => sprintf('%s:%s', $redisHost, $redisPort),
                'password' => $redisPassword,
                'prefix' => 'mdl_cache_',
                'serializer' => 1, // \Redis::SERIALIZER_PHP
                'compressor' => 0, // \cachestore_redis::COMPRESSOR_NONE
            ],
        ],
        'local_file' => [
            'type' => 'file',
            'config' => [
                'path' => '/tmp/local-cache-file',
                'autocreate' => 1,
            ],
        ],
    ],
    'rules' => [
        'application' => [
            // These get queried on almost every page
            // and don't need to be shared between instances,
            // so let's stick them on APCu for speeeeeeeed
            [
                'conditions' => [
                    'name' => 'core/langmenu',
                ],
                'stores' => ['apcu', 'redis'],
            ],
            [
                'conditions' => [
                    'name' => 'core/plugin_functions',
                ],
                'stores' => ['apcu', 'redis'],
            ],
            [
                'conditions' => [
                    'name' => 'core/string',
                ],
                'stores' => ['apcu', 'redis'],
            ],
            // HTMLPurifier spits out some big files,
            // so let's store it locally in tmpfs
            [
                'conditions' => [
                    'name' => 'core/htmlpurifier',
                ],
                'stores' => ['local_file'],
            ],
            // Other things that work locally can go to tmpfs
            [
                'conditions' => [
                    'canuselocalstore' => true,
                ],
                'stores' => ['local_file', 'redis'],
            ],
            // Everything else to Redis!
            ['stores' => ['redis']],
        ],
        'session' => [
            ['stores' => ['redis']],
        ],
        'request' => [],
    ],
];

$CFG->session_handler_class = '\core\session\redis';
$CFG->session_redis_host = $redisHost;
$CFG->session_redis_port = $redisPort;
$CFG->session_redis_database = 0;
$CFG->session_redis_auth = $redisPassword;
$CFG->session_redis_prefix = 'mdl_session_';

/*
 * URL and filesystem configuration
 */

$CFG->wwwroot = getenv('WWW_ROOT') ?: 'http://localhost';

$CFG->dataroot = getenv('DATA_ROOT') ?: '/var/www/moodledata';
$CFG->directorypermissions = 0777;

/*
 * Administration configuration
 */

$CFG->siteadmins = getenv('SITE_ADMINS') ?: null;
$CFG->alternative_component_cache = __DIR__ . '/core_component.php';
$CFG->upgradekey = getenv('UPGRADE_KEY') ?: null;
$CFG->disableupdateautodeploy = true;
$CFG->preventexecpath = true;

/*
 * Pass it off to Moodle core
 */

require_once __DIR__ . '/lib/setup.php';
