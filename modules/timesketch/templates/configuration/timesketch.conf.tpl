# Timesketch configuration

# Show debug information.
# Note: It is a security risk to have this enabled in production.
DEBUG = False

# Key for signing cookies and for CSRF protection.
#
# This should be a unique random string. Don't share this with anyone.
# To generate a key, you can for example use openssl:
# $ openssl rand -base64 32
SECRET_KEY = '${secret_key}'

# Setup the database.
#
# For more options, see the official documentation:
# https://pythonhosted.org/Flask-SQLAlchemy/config.html
# By default sqlite is used.
#
# NOTE: SQLite should only be used in development. Use PostgreSQL or MySQL in
# production.
SQLALCHEMY_DATABASE_URI = 'postgresql://${postgres_user}:${postgres_password}@${postgres_host}/${postgres_db}'

# Configure where your Elasticsearch server is located.
#
# Make sure that the OpenSearch server is properly secured and not accessible
# from the internet. See the following link for more information:
# http://www.elasticsearch.org/blog/scripting-security/
OPENSEARCH_HOST = '${opensearch_host}'
OPENSEARCH_PORT = '${opensearch_port}'
OPENSEARCH_USER = '${opensearch_user}'
OPENSEARCH_PASSWORD = '${opensearch_password}'
OPENSEARCH_SSL = True
OPENSEARCH_VERIFY_CERTS = True
OPENSEARCH_TIMEOUT = 10

# Define what labels should be defined that make it so that a sketch and
# timelines will not be deleted. This can be used to add a list of different
# labels that ensure that a sketch and it's associated timelines cannot be
# deleted.
LABELS_TO_PREVENT_DELETION = ['protected', 'preserved']

# Number of seconds before a timeout occurs in bulk operations in the
# OpenSearch client. This is expressed in Elastic Time Units, see:
# https://www.elastic.co/guide/en/elasticsearch/reference/current/\
# common-options.html#time-units
TIMEOUT_FOR_EVENT_IMPORT = '3m'

# Location for the configuration file of the data finder.
DATA_FINDER_PATH = '/etc/timesketch/data_finder.yaml'

#-------------------------------------------------------------------------------
# Single Sign On (SSO) configuration.

# Your web server can handle authentication for you by setting a environment
# variable when the user is successfully authenticated. The standard environment
# variable is REMOTE_USER and this is the default, but if your SSO system uses
# another name you can configure that here.

SSO_ENABLED = False
SSO_USER_ENV_VARIABLE = 'REMOTE_USER'

# Some SSO systems provides group information as environment variable.
# Timesketch can automatically create groups and add users as members.
# To enable this feature just provide the environment variable used in the SSO
# system of use.
SSO_GROUP_ENV_VARIABLE = None

# Different systems use different separators in the string returned in the
# environment variable.
SSO_GROUP_SEPARATOR = ';'

# Some SSO systems uses a special prefix for the group name to indicate that
# the user is not a member of that group. Set this if that is the case, i.e.
# '-'.
SSO_GROUP_NOT_MEMBER_SIGN = None

#-------------------------------------------------------------------------------
# Google Cloud Identity-Aware Proxy (Cloud IAP) authentication configuration.

# Cloud IAP controls access to your Timesketch server running on Google Cloud
# Platform. Cloud IAP works by verifying a user’s identity and determining if
# that user should be allowed to access the server.
#
# For this feature you will need to configure your Cloud IAP and HTTPS load-
# balancer. Follow the official documentation to get everything ready:
# https://cloud.google.com/iap/docs/enabling-compute-howto

# Enable Cloud IAP authentication support.
GOOGLE_IAP_ENABLED = False

# This information is available via the Google Cloud console:
# https://cloud.google.com/iap/docs/signed-headers-howto
GOOGLE_IAP_PROJECT_NUMBER = ''
GOOGLE_IAP_BACKEND_ID = ''

# DON'T EDIT: Google IAP expected audience is based on Cloud project number and
# backend ID.
GOOGLE_IAP_AUDIENCE = '/projects/{}/global/backendServices/{}'.format(
    GOOGLE_IAP_PROJECT_NUMBER,
    GOOGLE_IAP_BACKEND_ID
)

GOOGLE_IAP_ALGORITHM = 'ES256'
GOOGLE_IAP_ISSUER = 'https://cloud.google.com/iap'
GOOGLE_IAP_PUBLIC_KEY_URL = 'https://www.gstatic.com/iap/verify/public_key'

#-------------------------------------------------------------------------------
# Google Cloud OpenID Connect (OIDC) authentication configuration.

# Cloud OIDC controls access to your Timesketch server running on Google Cloud
# Platform. Cloud OIDC works by verifying a user’s identity and determining if
# that user should be allowed to access the server.

# Enable Cloud OIDC authentication support.
# For Google's federated identity, leave AUTH_URI and DICOVERY_URL to None.
# For others, refer to your OIDC provider configuration. Configuration can be
# obtain from the dicovery url. eg. https://accounts.google.com/.well-known/openid-configuration

# Some OIDC providers expects a specific Algorithm. If so, specify in ALGORITHM.
# Eg. HS256, HS384, HS512, RS256, RS384, RS512.
# For Google, leave it to None

GOOGLE_OIDC_ENABLED = False

GOOGLE_OIDC_AUTH_URL = None
GOOGLE_OIDC_DISCOVERY_URL = None
GOOGLE_OIDC_ALGORITHM = None

GOOGLE_OIDC_CLIENT_ID = None
GOOGLE_OIDC_CLIENT_SECRET = None

# If you need to authenticate an API client using OIDC you need to create
# an OAUTH client for "other", or for native applications.
# https://developers.google.com/identity/protocols/OAuth2ForDevices
GOOGLE_OIDC_API_CLIENT_ID = None
GOOGLE_OIDC_API_CLIENT_SECRET = None

# Limit access to a specific Google GSuite domain.
GOOGLE_OIDC_HOSTED_DOMAIN = None

# If populated only these users (email addresses) will be able to login to
# this server. This can be used when access should be limited to a specific
# set of users.
GOOGLE_OIDC_ALLOWED_USERS = []

#-------------------------------------------------------------------------------
# Upload and processing of Plaso storage files.

# To enable this feature you need to configure an upload directory and
# how to reach the Redis database used by the distributed task queue.
UPLOAD_ENABLED = True

# Folder for temporarily storage of Plaso dump files before being processed and
# inserted into the datastore.
UPLOAD_FOLDER = '/usr/share/timesketch/upload'

# Celery broker configuration. You need to change ip/port to where your Redis
# server is running.
CELERY_BROKER_URL = 'redis://${redis_host}:${redis_port}'
CELERY_RESULT_BACKEND = 'redis://${redis_host}:${redis_port}'

# File location to store the mappings used when Elastic indices are created
# for plaso files.
PLASO_MAPPING_FILE = '/etc/timesketch/plaso.mappings'
GENERIC_MAPPING_FILE = '/etc/timesketch/generic.mappings'

# Upper limits for the process memory that psort.py is allocated when ingesting
# plaso files. The size is in bytes, with the default value of
# 4294967296 or 4 GiB.
PLASO_UPPER_MEMORY_LIMIT = None

#-------------------------------------------------------------------------------
# Analyzers.

# Which analyzers to run automatically.
AUTO_SKETCH_ANALYZERS = []

# Optional specify any default arguments to pass to analyzers.
# The format is:
# {'analyzer1_name': {
#     'param1': 'value'
#   },
#   {'analyzer2_name': {
#       'param1': 'value'
#     }
#   }
# }
AUTO_SKETCH_ANALYZERS_KWARGS = {}
ANALYZERS_DEFAULT_KWARGS = {}

# Add all domains that are relevant to your enterprise here.
# All domains in this list are added to the list of watched
# domains and compared to other domains in the timeline to
# attempt to spot "phishy" domains.
DOMAIN_ANALYZER_WATCHED_DOMAINS = []

# Defines how deep into the most frequently visited top
# level domains the analyzer should include in its watch list.
DOMAIN_ANALYZER_WATCHED_DOMAINS_THRESHOLD = 10

# The minimum Jaccard distance for a domain to be considered
# similar to the domains in the watch list. The lower this number
# is the more domains will be included in the "phishy" domain
# category.
DOMAIN_ANALYZER_WATCHED_DOMAINS_SCORE_THRESHOLD = 0.75

# A list of domains that are frequent source of false positives
# in the "phishy" domain comparison, mostly CDNs and similar.
DOMAIN_ANALYZER_EXCLUDE_DOMAINS = ['ytimg.com', 'gstatic.com', 'yimg.com', 'akamaized.net', 'akamaihd.net', 's-microsoft.com', 'images-amazon.com', 'ssl-images-amazon.com', 'wikimedia.org', 'redditmedia.com', 'googleusercontent.com', 'googleapis.com', 'wikipedia.org', 'github.io', 'github.com']

# The threshold in minutes which the difference in timestamps has to cross in order to be
# detected as 'timestomping'.
NTFS_TIMESTOMP_ANALYZER_THRESHOLD = 10

# Safe Browsing API key for the URL analyzer.
SAFEBROWSING_API_KEY = ''

# For the other possible values of the two settings below, please refer to
# the Safe Browsing API reference at:
# https://developers.google.com/safe-browsing/v4/reference/rest

# Platforms to be looked at in Safe Browsing (PlatformType).
SAFEBROWSING_PLATFORMS = ['ANY_PLATFORM']

# Types to be looked at in Safe Browsing (ThreatType).
SAFEBROWSING_THREATTYPES = ['MALWARE']

#-------------------------------------------------------------------------------
# Enable experimental UI features.

ENABLE_EXPERIMENTAL_UI = False

#-------------------------------------------------------------------------------
# Email notifications.

ENABLE_EMAIL_NOTIFICATIONS = False
EMAIL_DOMAIN = 'localhost'
EMAIL_FROM_USER = 'nobody'
EMAIL_SMTP_SERVER = 'localhost'

# Only send emails to these users.
EMAIL_RECIPIENTS = []

# Configuration to construct URLs for resources.
EXTERNAL_HOST_URL = 'https://localhost'

#-------------------------------------------------------------------------------
# Sigma Settings

SIGMA_RULES_FOLDERS = ['/etc/timesketch/sigma/rules/']
SIGMA_CONFIG = '/etc/timesketch/sigma_config.yaml'
SIGMA_TAG_DELAY = 5
SIGMA_BLOCKLIST_CSV = '/etc/timesketch/sigma_blocklist.csv'

#-------------------------------------------------------------------------------
# Flask Settings
# Everything mentioned in https://flask-wtf.readthedocs.io/en/latest/config/ can be used.
# Max age in seconds for CSRF tokens. Default is 3600. If set to None, the CSRF token is valid for the life of the session.
# WTF_CSRF_TIME_LIMIT = 7200
# WTF_CSRF_ENABLED = False # Set this to False for UI-development purposes
#------
# GeoIP Analyzer Settings
#
# Disclaimer: Please note that the geolocation results obtained from this analyzer
# are indicative and based upon the accuracy of the configured datasource.

# The path to a MaxMind GeoIP database
MAXMIND_DB_PATH = ''

# The Account ID to access a MaxMind GeoIP web service
MAXMIND_WEB_ACCOUNT_ID = ''

# The license key to access a MaxMind GeoIP web service
MAXMIND_WEB_LICENSE_KEY = ''

# The host URL of a MaxMind GeoIP web service
MAXMIND_WEB_HOST = ''

# Scenarios
SCENARIOS_PATH = '/etc/timesketch/scenarios/scenarios.yaml'
INVESTIGATIONS_PATH = '/etc/timesketch/scenarios/investigations.yaml'
QUESTIONS_PATH = '/etc/timesketch/scenarios/questions.yaml'

# Intelligence tag metadata configuration
INTELLIGENCE_TAG_METADATA = '/etc/timesketch/intelligence_tag_metadata.yaml'