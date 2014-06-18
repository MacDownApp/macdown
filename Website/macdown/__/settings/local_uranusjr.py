from .base import *     # noqa

SECRET_KEY = '!)v2)@wjnmuye!0m0if(9)+gb6&8=t^sf!*ty3j3$lk71^3f$c'

DEBUG = True

TEMPLATE_DEBUG = True

DATABASES['default'] = {
    'ENGINE': 'django.db.backends.sqlite3',
    'NAME': os.path.join(BASE_DIR, 'db.sqlite3'),
}
