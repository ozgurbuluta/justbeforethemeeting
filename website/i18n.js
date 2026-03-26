(function () {
  const STORAGE_KEY = "jbtm_lang";
  const SUPPORTED = ["en", "tr"];

  function getPreferredLang() {
    const fromQuery = new URLSearchParams(window.location.search).get("lang");
    if (fromQuery && SUPPORTED.includes(fromQuery)) {
      return fromQuery;
    }
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored && SUPPORTED.includes(stored)) {
      return stored;
    }
    const nav = (navigator.language || "").toLowerCase();
    if (nav.startsWith("tr")) {
      return "tr";
    }
    return "en";
  }

  function get(obj, path) {
    return path.split(".").reduce(function (cur, key) {
      return cur == null ? undefined : cur[key];
    }, obj);
  }

  async function loadBundle(lang) {
    const res = await fetch("i18n/" + lang + ".json");
    if (!res.ok) {
      throw new Error("Failed to load locale: " + lang);
    }
    return res.json();
  }

  function setHtml(el, html) {
    if (!el) {
      return;
    }
    el.innerHTML = html;
  }

  async function applyLang(lang) {
    if (!SUPPORTED.includes(lang)) {
      lang = "en";
    }
    localStorage.setItem(STORAGE_KEY, lang);
    document.documentElement.lang = lang === "tr" ? "tr" : "en";

    const data = await loadBundle(lang);

    document.title = data.meta.title;
    const metaDesc = document.querySelector('meta[name="description"]');
    if (metaDesc) {
      metaDesc.setAttribute("content", data.meta.description);
    }

    document.querySelectorAll("[data-i18n]").forEach(function (el) {
      const key = el.getAttribute("data-i18n");
      const val = get(data, key);
      if (val != null) {
        el.textContent = val;
      }
    });

    setHtml(document.getElementById("cta-note"), data.hero.ctaNote);

    const fl = document.getElementById("features-list");
    if (fl && data.features && data.features.items) {
      fl.innerHTML = "";
      data.features.items.forEach(function (html) {
        const li = document.createElement("li");
        li.innerHTML = html;
        fl.appendChild(li);
      });
    }

    const hl = document.getElementById("how-list");
    if (hl && data.how && data.how.steps) {
      hl.innerHTML = "";
      data.how.steps.forEach(function (html) {
        const li = document.createElement("li");
        li.innerHTML = html;
        hl.appendChild(li);
      });
    }

    const dl = document.getElementById("download-link");
    if (dl && data.hero.cta) {
      dl.textContent = data.hero.cta;
    }

    const langSelect = document.getElementById("lang-select");
    if (langSelect) {
      langSelect.value = lang;
    }

    const foot = document.querySelector("footer p");
    if (foot && data.footer) {
      foot.textContent = data.footer;
    }
  }

  function setLangInURL(lang) {
    const url = new URL(window.location.href);
    url.searchParams.set("lang", lang);
    window.history.replaceState({}, "", url);
  }

  document.addEventListener("DOMContentLoaded", function () {
    const lang = getPreferredLang();
    const langSelect = document.getElementById("lang-select");
    if (langSelect) {
      langSelect.value = lang;
    }

    applyLang(lang).catch(function (err) {
      console.error(err);
    });

    if (langSelect) {
      langSelect.addEventListener("change", function () {
        const l = langSelect.value;
        applyLang(l).catch(function (err) {
          console.error(err);
        });
        setLangInURL(l);
      });
    }
  });
})();
