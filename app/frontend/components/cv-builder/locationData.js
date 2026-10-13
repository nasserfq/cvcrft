// Country and city suggestions for the CV builder's location fields.
// The CV stores English names, so every option carries its English value and
// an Arabic label for searching and display. Country names come from the
// browser (Intl.DisplayNames); cities are listed below for the countries most
// of our users live in. Anything else can still be typed by hand.

// ISO 3166-1 alpha-2 codes. Gulf countries first, so they lead the empty list.
const PRIORITY_COUNTRIES = ["SA", "AE", "KW", "QA", "BH", "OM", "EG", "JO"];
const COUNTRY_CODES = [
  "AD", "AE", "AF", "AG", "AI", "AL", "AM", "AO", "AR", "AS", "AT", "AU", "AW", "AX", "AZ",
  "BA", "BB", "BD", "BE", "BF", "BG", "BH", "BI", "BJ", "BL", "BM", "BN", "BO", "BQ", "BR",
  "BS", "BT", "BW", "BY", "BZ", "CA", "CC", "CD", "CF", "CG", "CH", "CI", "CK", "CL", "CM",
  "CN", "CO", "CR", "CU", "CV", "CW", "CX", "CY", "CZ", "DE", "DJ", "DK", "DM", "DO", "DZ",
  "EC", "EE", "EG", "ER", "ES", "ET", "FI", "FJ", "FK", "FM", "FO", "FR", "GA", "GB", "GD",
  "GE", "GF", "GG", "GH", "GI", "GL", "GM", "GN", "GP", "GQ", "GR", "GT", "GU", "GW", "GY",
  "HK", "HN", "HR", "HT", "HU", "ID", "IE", "IM", "IN", "IQ", "IR", "IS", "IT", "JE", "JM",
  "JO", "JP", "KE", "KG", "KH", "KI", "KM", "KN", "KP", "KR", "KW", "KY", "KZ", "LA", "LB",
  "LC", "LI", "LK", "LR", "LS", "LT", "LU", "LV", "LY", "MA", "MC", "MD", "ME", "MF", "MG",
  "MH", "MK", "ML", "MM", "MN", "MO", "MP", "MQ", "MR", "MS", "MT", "MU", "MV", "MW", "MX",
  "MY", "MZ", "NA", "NC", "NE", "NF", "NG", "NI", "NL", "NO", "NP", "NR", "NU", "NZ", "OM",
  "PA", "PE", "PF", "PG", "PH", "PK", "PL", "PM", "PR", "PS", "PT", "PW", "PY", "QA", "RE",
  "RO", "RS", "RU", "RW", "SA", "SB", "SC", "SD", "SE", "SG", "SH", "SI", "SK", "SL", "SM",
  "SN", "SO", "SR", "SS", "ST", "SV", "SX", "SY", "SZ", "TC", "TD", "TG", "TH", "TJ", "TK",
  "TL", "TM", "TN", "TO", "TR", "TT", "TV", "TW", "TZ", "UA", "UG", "US", "UY", "UZ", "VA",
  "VC", "VE", "VG", "VI", "VN", "VU", "WF", "WS", "XK", "YE", "YT", "ZA", "ZM", "ZW",
];

// Names the browser gets wrong for our users, or spells in ways a CV shouldn't.
const COUNTRY_OVERRIDES = {
  PS: { en: "Palestine", ar: "فلسطين" },
  SA: { en: "Saudi Arabia", ar: "السعودية" },
  TR: { en: "Turkey", ar: "تركيا" },
};

// [English, Arabic] per country code.
export const CITIES = {
  SA: [
    ["Riyadh", "الرياض"], ["Jeddah", "جدة"], ["Makkah", "مكة المكرمة"], ["Madinah", "المدينة المنورة"],
    ["Dammam", "الدمام"], ["Al Khobar", "الخبر"], ["Dhahran", "الظهران"], ["Jubail", "الجبيل"],
    ["Al Ahsa", "الأحساء"], ["Hofuf", "الهفوف"], ["Qatif", "القطيف"], ["Abqaiq", "بقيق"],
    ["Ras Tanura", "رأس تنورة"], ["Al Khafji", "الخفجي"], ["Hafar Al Batin", "حفر الباطن"],
    ["Taif", "الطائف"], ["Yanbu", "ينبع"], ["Rabigh", "رابغ"], ["Thuwal", "ثول"], ["Al Ula", "العلا"],
    ["NEOM", "نيوم"], ["Tabuk", "تبوك"], ["Buraidah", "بريدة"], ["Unaizah", "عنيزة"], ["Hail", "حائل"],
    ["Abha", "أبها"], ["Khamis Mushait", "خميس مشيط"], ["Bisha", "بيشة"], ["Najran", "نجران"],
    ["Jazan", "جازان"], ["Sabya", "صبيا"], ["Al Baha", "الباحة"], ["Al Qunfudhah", "القنفذة"],
    ["Arar", "عرعر"], ["Sakaka", "سكاكا"], ["Al Qurayyat", "القريات"], ["Al Kharj", "الخرج"],
    ["Diriyah", "الدرعية"], ["Al Majmaah", "المجمعة"], ["Al Zulfi", "الزلفي"], ["Shaqra", "شقراء"],
    ["Dawadmi", "الدوادمي"],
  ],
  AE: [
    ["Dubai", "دبي"], ["Abu Dhabi", "أبوظبي"], ["Sharjah", "الشارقة"], ["Ajman", "عجمان"],
    ["Ras Al Khaimah", "رأس الخيمة"], ["Fujairah", "الفجيرة"], ["Umm Al Quwain", "أم القيوين"],
    ["Al Ain", "العين"],
  ],
  KW: [
    ["Kuwait City", "مدينة الكويت"], ["Hawalli", "حولي"], ["Salmiya", "السالمية"],
    ["Farwaniya", "الفروانية"], ["Al Ahmadi", "الأحمدي"], ["Jahra", "الجهراء"],
    ["Mubarak Al-Kabeer", "مبارك الكبير"],
  ],
  QA: [
    ["Doha", "الدوحة"], ["Al Rayyan", "الريان"], ["Al Wakrah", "الوكرة"], ["Lusail", "لوسيل"],
    ["Al Khor", "الخور"], ["Umm Salal", "أم صلال"], ["Mesaieed", "مسيعيد"],
  ],
  BH: [
    ["Manama", "المنامة"], ["Muharraq", "المحرق"], ["Riffa", "الرفاع"], ["Isa Town", "مدينة عيسى"],
    ["Hamad Town", "مدينة حمد"], ["Sitra", "سترة"],
  ],
  OM: [
    ["Muscat", "مسقط"], ["Seeb", "السيب"], ["Salalah", "صلالة"], ["Sohar", "صحار"], ["Nizwa", "نزوى"],
    ["Sur", "صور"], ["Ibri", "عبري"], ["Barka", "بركاء"], ["Duqm", "الدقم"],
  ],
  EG: [
    ["Cairo", "القاهرة"], ["New Cairo", "القاهرة الجديدة"], ["Giza", "الجيزة"],
    ["6th of October City", "مدينة السادس من أكتوبر"], ["Alexandria", "الإسكندرية"],
    ["Mansoura", "المنصورة"], ["Tanta", "طنطا"], ["Zagazig", "الزقازيق"], ["Port Said", "بورسعيد"],
    ["Suez", "السويس"], ["Ismailia", "الإسماعيلية"], ["Asyut", "أسيوط"], ["Luxor", "الأقصر"],
    ["Aswan", "أسوان"], ["Hurghada", "الغردقة"], ["Sharm El Sheikh", "شرم الشيخ"],
  ],
  JO: [
    ["Amman", "عمان"], ["Zarqa", "الزرقاء"], ["Irbid", "إربد"], ["Aqaba", "العقبة"], ["Salt", "السلط"],
    ["Madaba", "مادبا"], ["Jerash", "جرش"], ["Karak", "الكرك"], ["Mafraq", "المفرق"],
  ],
  LB: [
    ["Beirut", "بيروت"], ["Tripoli", "طرابلس"], ["Sidon", "صيدا"], ["Tyre", "صور"], ["Jounieh", "جونية"],
    ["Zahle", "زحلة"], ["Byblos", "جبيل"],
  ],
  IQ: [
    ["Baghdad", "بغداد"], ["Basra", "البصرة"], ["Erbil", "أربيل"], ["Mosul", "الموصل"], ["Najaf", "النجف"],
    ["Karbala", "كربلاء"], ["Sulaymaniyah", "السليمانية"], ["Kirkuk", "كركوك"], ["Duhok", "دهوك"],
  ],
  SY: [
    ["Damascus", "دمشق"], ["Aleppo", "حلب"], ["Homs", "حمص"], ["Latakia", "اللاذقية"], ["Hama", "حماة"],
    ["Tartus", "طرطوس"],
  ],
  PS: [
    ["Jerusalem", "القدس"], ["Ramallah", "رام الله"], ["Gaza", "غزة"], ["Nablus", "نابلس"],
    ["Hebron", "الخليل"], ["Bethlehem", "بيت لحم"], ["Jenin", "جنين"],
  ],
  YE: [
    ["Sanaa", "صنعاء"], ["Aden", "عدن"], ["Taiz", "تعز"], ["Mukalla", "المكلا"], ["Hodeidah", "الحديدة"],
    ["Ibb", "إب"],
  ],
  SD: [["Khartoum", "الخرطوم"], ["Omdurman", "أم درمان"], ["Port Sudan", "بورتسودان"], ["Kassala", "كسلا"]],
  LY: [["Tripoli", "طرابلس"], ["Benghazi", "بنغازي"], ["Misrata", "مصراتة"]],
  TN: [["Tunis", "تونس"], ["Sfax", "صفاقس"], ["Sousse", "سوسة"], ["Kairouan", "القيروان"], ["Bizerte", "بنزرت"]],
  DZ: [
    ["Algiers", "الجزائر"], ["Oran", "وهران"], ["Constantine", "قسنطينة"], ["Annaba", "عنابة"],
    ["Blida", "البليدة"], ["Setif", "سطيف"],
  ],
  MA: [
    ["Casablanca", "الدار البيضاء"], ["Rabat", "الرباط"], ["Marrakesh", "مراكش"], ["Fes", "فاس"],
    ["Tangier", "طنجة"], ["Agadir", "أكادير"], ["Meknes", "مكناس"], ["Oujda", "وجدة"],
  ],
  TR: [["Istanbul", "إسطنبول"], ["Ankara", "أنقرة"], ["Izmir", "إزمير"]],
  GB: [["London", "لندن"], ["Manchester", "مانشستر"], ["Birmingham", "برمنغهام"]],
  US: [
    ["New York", "نيويورك"], ["San Francisco", "سان فرانسيسكو"], ["Los Angeles", "لوس أنجلوس"],
    ["Houston", "هيوستن"], ["Washington, D.C.", "واشنطن"],
  ],
  CA: [["Toronto", "تورونتو"], ["Montreal", "مونتريال"], ["Vancouver", "فانكوفر"]],
  IN: [["Mumbai", "مومباي"], ["New Delhi", "نيودلهي"], ["Bengaluru", "بنغالورو"], ["Hyderabad", "حيدر آباد"]],
  PK: [["Karachi", "كراتشي"], ["Lahore", "لاهور"], ["Islamabad", "إسلام آباد"]],
  MY: [["Kuala Lumpur", "كوالالمبور"]],
  PH: [["Manila", "مانيلا"]],
};

// Strip accents and curly quotes so names pass the builder's English check
// and print cleanly in the PDF fonts.
const toPlainLatin = (s) => s.normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[‘’]/g, "'");

let countriesCache = null;

export function getCountries() {
  if (countriesCache) return countriesCache;
  let en = null;
  let ar = null;
  try {
    en = new Intl.DisplayNames(["en"], { type: "region" });
    ar = new Intl.DisplayNames(["ar"], { type: "region" });
  } catch {
    // Old browsers without Intl.DisplayNames: only the countries we name ourselves.
  }
  const ordered = [...PRIORITY_COUNTRIES, ...COUNTRY_CODES.filter((c) => !PRIORITY_COUNTRIES.includes(c))];
  countriesCache = ordered
    .map((code) => {
      const override = COUNTRY_OVERRIDES[code];
      const enName = override?.en || (en && en.of(code));
      const arName = override?.ar || (ar && ar.of(code));
      if (!enName || enName === code) return null;
      return { code, value: toPlainLatin(enName), ar: arName || enName };
    })
    .filter(Boolean);
  return countriesCache;
}

// Cities for the country the user picked, or every listed city if the country
// field is empty or unknown. Each city also knows its country, so picking one
// can fill an empty country field.
export function getCities(countryValue) {
  const countries = getCountries();
  const match = countryValue && findOption(countries, countryValue);
  const codes = match && CITIES[match.code] ? [match.code] : Object.keys(CITIES);
  return codes.flatMap((code) => {
    const country = countries.find((c) => c.code === code);
    return CITIES[code].map(([value, ar]) => ({
      code: `${code}-${value}`,
      value,
      ar,
      country: country?.value,
      countryAr: country?.ar,
    }));
  });
}

// Loose matching for Arabic and English: case, Arabic diacritics, the alef
// forms, taa marbuta and alef maqsura, and a leading "ال" or "al".
export function normalize(s) {
  return toPlainLatin(String(s || ""))
    .toLowerCase()
    .replace(/[ً-ٰٕـ]/g, "")
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ة/g, "ه")
    .replace(/ى/g, "ي")
    .replace(/[-'.,]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

const stripArticle = (s) => s.replace(/^(ال|al )/, "");

// Exact match on either language (used to turn a typed Arabic name into its
// English value on blur).
export function findOption(options, text) {
  const q = normalize(text);
  if (!q) return null;
  return options.find((o) => normalize(o.value) === q || normalize(o.ar) === q) ||
    options.find((o) => stripArticle(normalize(o.value)) === stripArticle(q) || stripArticle(normalize(o.ar)) === stripArticle(q)) ||
    null;
}

export function filterOptions(options, text, limit = 50) {
  const q = normalize(text);
  if (!q) return options.slice(0, limit);
  const bare = stripArticle(q);
  const starts = [];
  const contains = [];
  for (const o of options) {
    const names = [normalize(o.value), normalize(o.ar)];
    if (names.some((n) => n.startsWith(q) || stripArticle(n).startsWith(bare))) starts.push(o);
    else if (names.some((n) => n.includes(q))) contains.push(o);
    if (starts.length >= limit) break;
  }
  return [...starts, ...contains].slice(0, limit);
}
