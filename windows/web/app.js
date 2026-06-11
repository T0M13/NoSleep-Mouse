const $ = (id) => document.getElementById(id);

let state = {
  enabled: false,
  intervalSec: 60,
  method: "mouse",
  hoursEnabled: false,
  fromTime: "09:00",
  toTime: "17:00",
};

// ---- helpers ----
function fmt(sec) {
  if (sec == null) return "--";
  if (sec >= 60) {
    const m = Math.floor(sec / 60);
    const s = sec % 60;
    return `${m}:${String(s).padStart(2, "0")}`;
  }
  return `${sec}s`;
}

async function post(patch) {
  const res = await fetch("/api/config", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(patch),
  });
  apply(await res.json());
}

async function poll() {
  try {
    const res = await fetch("/api/status");
    apply(await res.json());
  } catch (e) {
    $("ns_status").textContent = "helper stopped";
    $("ns_clock").textContent = "--";
  }
}

// ---- render ----
function apply(s) {
  state = s;

  $("toggleEnabled").checked = s.enabled;
  $("toggleHours").checked = s.hoursEnabled;

  // interval buttons
  const presets = [30, 60, 300];
  document.querySelectorAll("#intervalControls button[data-sec]").forEach((b) => {
    b.classList.toggle("active", s.enabled && Number(b.dataset.sec) === s.intervalSec);
  });
  const isCustom = !presets.includes(s.intervalSec);
  $("customBtn").classList.toggle("active", s.enabled && isCustom);
  if (isCustom) {
    $("customWrap").classList.remove("hidden");
    if (document.activeElement !== $("customSec")) $("customSec").value = s.intervalSec;
  }

  // method buttons
  document.querySelectorAll("#methodControls button").forEach((b) => {
    b.classList.toggle("active", b.dataset.method === s.method);
  });

  // movement (only relevant for the mouse method)
  $("moveBlock").classList.toggle("hidden", s.method !== "mouse");
  document.querySelectorAll("#dirControls button").forEach((b) => {
    b.classList.toggle("active", b.dataset.dir === s.moveDir);
  });
  if (document.activeElement !== $("moveDistance")) $("moveDistance").value = s.moveDistance;

  // hours
  $("hoursWrap").classList.toggle("hidden", !s.hoursEnabled);
  if (document.activeElement !== $("fromTime")) $("fromTime").value = s.fromTime;
  if (document.activeElement !== $("toTime")) $("toTime").value = s.toTime;

  // clock + status
  if (!s.enabled) {
    $("ns_clock").textContent = "off";
    $("ns_status").textContent = "paused";
  } else if (s.hoursEnabled && !s.inActiveHours) {
    $("ns_clock").textContent = "zzz";
    $("ns_status").textContent = "outside active hours";
  } else {
    $("ns_clock").textContent = fmt(s.secondsUntilNext);
    $("ns_status").textContent = "staying online";
  }

  $("ns_count").textContent =
    s.count > 0 ? `${s.count} nudge${s.count === 1 ? "" : "s"} this session` : "";
}

// ---- events ----
$("toggleEnabled").addEventListener("change", (e) => post({ enabled: e.target.checked }));

document.querySelectorAll("#intervalControls button[data-sec]").forEach((b) => {
  b.addEventListener("click", () => {
    $("customWrap").classList.add("hidden");
    post({ intervalSec: Number(b.dataset.sec), enabled: true });
  });
});

$("customBtn").addEventListener("click", () => {
  $("customWrap").classList.toggle("hidden");
  if (!$("customWrap").classList.contains("hidden")) $("customSec").focus();
});

$("customSec").addEventListener("change", (e) => {
  let v = Math.min(86400, Math.max(5, Number(e.target.value) || 60));
  post({ intervalSec: v, enabled: true });
});

document.querySelectorAll("#methodControls button").forEach((b) => {
  b.addEventListener("click", () => post({ method: b.dataset.method }));
});

document.querySelectorAll("#dirControls button").forEach((b) => {
  b.addEventListener("click", () => post({ moveDir: b.dataset.dir, method: "mouse" }));
});

$("moveDistance").addEventListener("change", (e) => {
  let v = Math.min(2000, Math.max(1, Number(e.target.value) || 60));
  post({ moveDistance: v });
});

$("toggleHours").addEventListener("change", (e) => post({ hoursEnabled: e.target.checked }));
$("fromTime").addEventListener("change", (e) => post({ fromTime: e.target.value }));
$("toTime").addEventListener("change", (e) => post({ toTime: e.target.value }));

$("quitBtn").addEventListener("click", async () => {
  if (!confirm("Stop the helper? You'll go idle in your apps again.")) return;
  try { await fetch("/api/quit", { method: "POST" }); } catch (e) {}
  $("ns_clock").textContent = "--";
  $("ns_status").textContent = "helper stopped";
  document.body.style.opacity = 0.5;
});

// ---- dark mode (persisted in browser) ----
function setDark(on) {
  document.body.classList.toggle("dark", on);
  $("toggleDark").checked = on;
  localStorage.setItem("ns_dark", on ? "1" : "0");
}
$("toggleDark").addEventListener("change", (e) => setDark(e.target.checked));
const themeParam = new URLSearchParams(location.search).get("theme"); // ?theme=dark|light
setDark(
  themeParam
    ? themeParam === "dark"
    : localStorage.getItem("ns_dark") === "1" ||
        (localStorage.getItem("ns_dark") === null &&
          matchMedia("(prefers-color-scheme: dark)").matches)
);

// ---- start ----
poll();
setInterval(poll, 1000);
