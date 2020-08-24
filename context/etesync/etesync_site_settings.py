import os

BASE_DIR = os.environ.get('BASE_DIR', '/etesync')

DEBUG = bool(os.environ.get('DEBUG', False))

ALLOWED_HOSTS = os.environ.get('DJANGO_HOSTS','*').split(',')

LANGUAGE_CODE = os.environ.get('DJANGO_LC','en-us')

USE_TZ = os.environ.get('USE_TZ', False)

TIME_ZONE = os.environ.get('TIME_ZONE', 'UTC')

SECRET_FILE = os.environ.get('SECRET_FILE')

if os.environ.get('USE_POSTGRES', '') == '1':
  DATABASES = {
    'default': {
      'ENGINE': 'django.db.backends.postgresql',
      'NAME': os.environ.get('DATABASE_NAME', 'etesync'),
      'USER': os.environ.get('DATABASE_USER', 'etesync'),
      'PASSWORD': os.environ.get('DATABASE_PASSWORD', 'etesync'),
      'HOST': os.environ.get('DATABASE_HOST', ''),
      'PORT': os.environ.get('DATABASE_PORT', '5432')
    }
  }