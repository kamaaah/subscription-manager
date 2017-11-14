from __future__ import print_function, division, absolute_import

# Copyright (c) 2011 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public License,
# version 2 (GPLv2). There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.
#
# Red Hat trademarks are not licensed under GPLv2. No permission is
# granted to use or replicate Red Hat trademarks that are incorporated
# in this software or its documentation.
#
import gettext
import locale
import logging

import six

log = logging.getLogger(__name__)

# Localization domain:
APP = 'rhsm'
# Directory where translations are deployed:
DIR = '/usr/share/locale/'


def configure_i18n():
    """
    Configure internationalization for the application. Should only be
    called once per invocation. (once for CLI, once for GUI)
    """
    import locale
    try:
        locale.setlocale(locale.LC_ALL, '')
    except locale.Error:
        locale.setlocale(locale.LC_ALL, 'C')
    configure_gettext()


def configure_gettext():
    """Configure gettext for all RHSM-related code.

    Since Glade internally uses gettext, we need to use the C-level bindings in locale to adjust the encoding.

    See https://docs.python.org/2/library/locale.html#access-to-message-catalogs

    Exposed as its own function so that it can be called safely in the initial-setup case.
    """
    gettext.bindtextdomain(APP, DIR)
    gettext.textdomain(APP)
    gettext.bind_textdomain_codeset(APP, 'UTF-8')
    locale.bind_textdomain_codeset(APP, 'UTF-8')


translation = gettext.translation(APP, fallback=True)
if six.PY3:  # gettext returns unicode in Python 3
    ugettext = translation.gettext
    ungettext = translation.ngettext
else:
    ugettext = translation.ugettext
    ungettext = translation.ungettext


class Locale(object):
    """
    Class used for changing languages on the fly
    """

    languages = {}
    converter = {}

    @classmethod
    def set_gettext_method(cls, language):
        """
        Set gettext method and locale for specified language. This method is
        intended for changing language on the fly, because rhsm service can
        be used by many users with different language preferences at the
        same time.
        :param language: String representing locale
                (e.g. de, de_DE, de_DE.utf-8, de_DE.UTF-8)
        """
        global ugettext, ungettext
        lang = None

        if language != '':
            # When we already found some working alternative for language code, then use it
            if language in cls.converter:
                language = cls.converter[language]
            if language not in cls.languages.keys():
                # Try to find given language
                try:
                    lang = gettext.translation(APP, DIR, languages=[language])
                except IOError as err:
                    log.info('Could not import locale for %s: %s' % (language, err))
                    # When original language was not found, then we will try another
                    # alternatives.
                    orig_language = None
                    # For similar case: 'de'
                    if '_' not in language:
                        orig_language = language
                        language += '_' + language.upper()
                    # For similar cases: 'de_AT' (Austria), 'de_LU' (Luxembourg)
                    elif language[0:2] != language[3:5]:
                        orig_language = language
                        language = language[0:2] + '_' + language[0:2].upper() + language[5:]
                    if orig_language:
                        try:
                            lang = gettext.translation(APP, DIR, languages=[language])
                        except IOError as err:
                            log.info('Could not import locale either for %s: %s' % (language, err))
                        else:
                            log.debug('Using new locale for language: %s' % language)
                            cls.languages[language] = lang
                            cls.converter[orig_language] = language
                else:
                    log.debug('Using new locale for language: %s' % language)
                    cls.languages[language] = lang
            else:
                log.debug('Reusing locale for language: %s' % language)
                lang = cls.languages[language]

        if lang is not None:

            # Set locale, because rhsm.connection use it
            if '_' not in language:
                language += '_' + language.upper()
            if language.upper().endswith('.UTF-8'):
                locale.setlocale(locale.LC_ALL, language)
            else:
                locale.setlocale(locale.LC_ALL, language + ".UTF-8")

            # Change gettext method according language
            if six.PY3:
                ugettext = lang.gettext
                ungettext = lang.ngettext
            else:
                ugettext = lang.gettext
                ungettext = lang.ngettext
        else:
            # When no locale was specified or locale is not supported,
            # then fall back to English language
            global translation
            translation = gettext.translation(APP, fallback=True)
            locale.setlocale(locale.LC_ALL, "C")
            if six.PY3:
                ugettext = translation.gettext
                ungettext = translation.ngettext
            else:
                ugettext = translation.ugettext
                ungettext = translation.ungettext
