.pragma library
.import "i18n/en.js" as L_en
.import "i18n/de.js" as L_de
.import "i18n/es.js" as L_es
.import "i18n/fr.js" as L_fr
.import "i18n/pt.js" as L_pt
.import "i18n/it.js" as L_it
.import "i18n/nl.js" as L_nl
.import "i18n/pl.js" as L_pl
.import "i18n/ru.js" as L_ru
.import "i18n/uk.js" as L_uk
.import "i18n/tr.js" as L_tr
.import "i18n/cs.js" as L_cs
.import "i18n/sv.js" as L_sv
.import "i18n/fi.js" as L_fi
.import "i18n/nb.js" as L_nb
.import "i18n/da.js" as L_da
.import "i18n/ro.js" as L_ro
.import "i18n/hu.js" as L_hu
.import "i18n/el.js" as L_el
.import "i18n/hi.js" as L_hi
.import "i18n/id.js" as L_id
.import "i18n/vi.js" as L_vi
.import "i18n/th.js" as L_th
.import "i18n/ja.js" as L_ja
.import "i18n/ko.js" as L_ko
.import "i18n/zh_CN.js" as L_zh_CN
.import "i18n/zh_TW.js" as L_zh_TW
.import "i18n/ar.js" as L_ar
.import "i18n/he.js" as L_he
.import "i18n/fa.js" as L_fa

// Runtime UI catalogue. Each language's texts live in i18n/<language>.js
// (one file per language, so none grows large); every translated catalogue
// is an overlay on English: a missing key falls back on its own instead of
// breaking the whole locale.
var catalog = {}

var languageMeta = {
  en: { locale: "en_US" },
  de: { locale: "de_DE" },
  es: { locale: "es_ES" },
  fr: { locale: "fr_FR" },
  pt: { locale: "pt_BR" },
  ru: { locale: "ru_RU" },
  uk: { locale: "uk_UA" },
  pl: { locale: "pl_PL" },
  it: { locale: "it_IT" },
  nl: { locale: "nl_NL" },
  tr: { locale: "tr_TR" },
  cs: { locale: "cs_CZ" },
  sv: { locale: "sv_SE" },
  fi: { locale: "fi_FI" },
  nb: { locale: "nb_NO" },
  da: { locale: "da_DK" },
  ro: { locale: "ro_RO" },
  hu: { locale: "hu_HU" },
  el: { locale: "el_GR" },
  zh_CN: { locale: "zh_CN" },
  zh_TW: { locale: "zh_TW" },
  ja: { locale: "ja_JP" },
  ko: { locale: "ko_KR" },
  ar: { locale: "ar_SA", rtl: true },
  he: { locale: "he_IL", rtl: true },
  fa: { locale: "fa_IR", rtl: true },
  hi: { locale: "hi_IN" },
  id: { locale: "id_ID" },
  vi: { locale: "vi_VN" },
  th: { locale: "th_TH" }
}

// Each language in its own name, for the language picker.
var languageNames = {
  en: "English", de: "Deutsch", es: "Español", fr: "Français", pt: "Português", ru: "Русский",
  uk: "Українська", pl: "Polski", it: "Italiano", nl: "Nederlands", tr: "Türkçe", cs: "Čeština",
  sv: "Svenska", fi: "Suomi", nb: "Norsk bokmål", da: "Dansk", ro: "Română", hu: "Magyar",
  el: "Ελληνικά", zh_CN: "简体中文", zh_TW: "繁體中文", ja: "日本語", ko: "한국어", ar: "العربية",
  he: "עברית", fa: "فارسی", hi: "हिन्दी", id: "Bahasa Indonesia", vi: "Tiếng Việt", th: "ไทย"
}

function addCatalog(language, entries) {
  var target = catalog[language] || (catalog[language] = {})
  for (var key in entries) target[key] = entries[key]
}

function languageName(language) {
  return languageNames[language] || language
}

// "auto" or a supported language code; anything else resolves to "auto".
function resolvedLanguage(choice, localeName) {
  var chosen = String(choice || "auto")
  return chosen !== "auto" && languageMeta[chosen] ? chosen : languageForLocale(localeName)
}

function languageForLocale(localeName) {
  var normalized = String(localeName || "").toLowerCase().replace(/-/g, "_")
  var base = normalized.split(/[_.@]/)[0]
  if (base === "zh") {
    if (normalized.indexOf("tw") >= 0 || normalized.indexOf("hk") >= 0
        || normalized.indexOf("mo") >= 0 || normalized.indexOf("hant") >= 0) return "zh_TW"
    return "zh_CN"
  }
  // Accept legacy libc/Java aliases as well as Norwegian locale variants.
  if (base === "iw") base = "he"
  if (base === "in") base = "id"
  if (base === "no" || base === "nn") base = "nb"
  return languageMeta[base] ? base : "en"
}

function localeName(language) {
  var meta = languageMeta[language] || languageMeta.en
  return meta.locale
}

// External services generally accept the ISO 639 base language, while the UI
// keeps region-aware catalogue IDs for Chinese.
function serviceLanguage(language) {
  return String(language || "en").split("_")[0]
}

function isRightToLeft(language) {
  return !!(languageMeta[language] && languageMeta[language].rtl)
}

function supportedLanguages() {
  return Object.keys(languageMeta)
}

function text(language, key, values) {
  var languageCatalog = catalog[language] || catalog.en
  var value = languageCatalog[key]
  if (value === undefined) value = catalog.en[key]
  if (value === undefined) return key

  var replacements = values || {}
  return String(value).replace(/\{([^}]+)\}/g, function(match, name) {
    return replacements[name] === undefined ? match : String(replacements[name])
  })
}

// ---- The languages, from i18n/ ------------------------------------------

addCatalog("en", L_en.catalog)
addCatalog("de", L_de.catalog)
addCatalog("es", L_es.catalog)
addCatalog("fr", L_fr.catalog)
addCatalog("pt", L_pt.catalog)
addCatalog("it", L_it.catalog)
addCatalog("nl", L_nl.catalog)
addCatalog("pl", L_pl.catalog)
addCatalog("ru", L_ru.catalog)
addCatalog("uk", L_uk.catalog)
addCatalog("tr", L_tr.catalog)
addCatalog("cs", L_cs.catalog)
addCatalog("sv", L_sv.catalog)
addCatalog("fi", L_fi.catalog)
addCatalog("nb", L_nb.catalog)
addCatalog("da", L_da.catalog)
addCatalog("ro", L_ro.catalog)
addCatalog("hu", L_hu.catalog)
addCatalog("el", L_el.catalog)
addCatalog("hi", L_hi.catalog)
addCatalog("id", L_id.catalog)
addCatalog("vi", L_vi.catalog)
addCatalog("th", L_th.catalog)
addCatalog("ja", L_ja.catalog)
addCatalog("ko", L_ko.catalog)
addCatalog("zh_CN", L_zh_CN.catalog)
addCatalog("zh_TW", L_zh_TW.catalog)
addCatalog("ar", L_ar.catalog)
addCatalog("he", L_he.catalog)
addCatalog("fa", L_fa.catalog)
