(() => {
  "use strict";

  const STORAGE_KEY = "starship-command.player-id";
  const DIRECTIONS = ["north", "south", "east", "west", "forward", "back", "left", "right"];
  const DIRECTION_ALIASES = { n: "north", s: "south", e: "east", w: "west", f: "forward", fwd: "forward", b: "back", r: "right" };
  const HELP = [
    "COMMANDS",
    "  look (l)                   describe your surroundings",
    "  go <direction>             move: north, south, east, west, forward, back, left, right",
    "  n / s / e / w / f / b      shortcuts; a bare direction like 'left' also works",
    "  take <item>                pick up an item (partial names are fine)",
    "  inventory (i)              list what you are carrying",
    "  launch                     repair and relaunch the ship (at the Crash Site)",
    "  log                        show your recent actions",
    "  restart                    start the mission over",
    "  clear                      clear the screen",
    "  logout                     switch commander",
    "Arrow keys browse previous commands. The buttons on the right do the same things.",
  ];

  const $ = (id) => document.getElementById(id);
  const output = $("output");
  const input = $("command");
  const loginDialog = $("login");

  let playerId = null;
  let state = null;
  let busy = false;
  const history = [];
  let historyIndex = 0;

  // localStorage can be unavailable (private windows, blocked storage)
  const storage = {
    get() { try { return localStorage.getItem(STORAGE_KEY); } catch { return null; } },
    set(value) { try { localStorage.setItem(STORAGE_KEY, value); } catch { /* not persisted */ } },
    clear() { try { localStorage.removeItem(STORAGE_KEY); } catch { /* nothing stored */ } },
  };

  /* ---------- output ---------- */

  function print(text, kind = "info") {
    const line = document.createElement("p");
    line.className = `line ${kind}`;
    line.textContent = text;
    output.append(line);
    output.scrollTop = output.scrollHeight;
  }

  function el(tag, props = {}, children = []) {
    const node = Object.assign(document.createElement(tag), props);
    node.append(...children);
    return node;
  }

  function describe() {
    const { location, items, exits } = state;
    print(`— ${location.name} —`, "title");
    print(location.description);
    if (items.length) print(`You see: ${items.map((i) => i.name).join(", ")}`, "success");
    print(`Exits: ${exits.map((e) => e.direction).join(", ")}`, "dim");
  }

  function formatDuration(seconds) {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return m ? `${m}m ${s}s` : `${s}s`;
  }

  /* ---------- side panel ---------- */

  function render(next) {
    state = next;
    const { player, location, items, exits, inventory, mission } = state;

    $("callsign").textContent = mission.complete ? `CMDR ${player.username} · LAUNCHED` : `CMDR ${player.username}`;
    $("pips").replaceChildren(
      ...Array.from({ length: mission.required }, (_, i) =>
        el("span", { className: i < mission.collected ? "pip on" : "pip", title: `${mission.collected}/${mission.required} components` }))
    );
    $("pips").setAttribute("aria-label", `${mission.collected} of ${mission.required} components recovered`);
    $("logout").hidden = false;

    $("loc-name").textContent = location.name;
    $("loc-desc").textContent = location.description;

    $("exits").replaceChildren(...exits.map((exit) =>
      el("button", { type: "button", onclick: () => submit(`go ${exit.direction}`) }, [
        exit.direction, " ", el("span", { className: "dest", textContent: `→ ${exit.location_name}` }),
      ])
    ));

    $("items").replaceChildren(...(items.length
      ? items.map((item) => el("li", {}, [
          el("span", { textContent: item.name, title: item.description }),
          el("button", { type: "button", textContent: "Take", onclick: () => submit(`take ${item.name}`) }),
        ]))
      : [el("li", { className: "empty", textContent: "Nothing of interest." })]));

    $("inventory").replaceChildren(...(inventory.length
      ? inventory.map((item) => el("li", { textContent: item.name, title: item.description }))
      : [el("li", { className: "empty", textContent: "Empty." })]));

    const ready = location.is_start && mission.collected === mission.required && !mission.complete;
    $("launch").classList.toggle("ready", ready);
  }

  function renderLog(entries) {
    $("log").replaceChildren(...entries.map((entry) => el("li", {}, [
      el("time", { dateTime: entry.time, textContent: new Date(entry.time).toLocaleTimeString() }),
      entry.details || entry.action,
    ])));
  }

  /* ---------- api ---------- */

  async function api(method, path, body) {
    const response = await fetch(path, {
      method,
      headers: body ? { "Content-Type": "application/json" } : {},
      body: body ? JSON.stringify(body) : undefined,
    });
    let data = null;
    try { data = await response.json(); } catch { /* non-JSON error page */ }
    return { status: response.status, data };
  }

  // POST a game action for the current player and redraw from the returned state
  async function act(action, body) {
    const { status, data } = await api("POST", `/api/players/${playerId}/${action}`, body);
    if (status === 404) {
      print("Your commander record could not be found. Please sign in again.", "error");
      logout();
      return null;
    }
    if (!data || !data.state) {
      print((data && data.message) || "No response from the ship's computer.", "error");
      return null;
    }
    render(data.state);
    refreshLog();
    return data;
  }

  async function refreshLog() {
    const { status, data } = await api("GET", `/api/players/${playerId}/log?limit=12`);
    if (status === 200 && Array.isArray(data)) renderLog(data);
  }

  /* ---------- commands ---------- */

  const commands = {
    help() {
      HELP.forEach((line, i) => print(line, i === 0 ? "title" : "dim"));
    },

    async look() {
      if (await act("look")) describe();
    },

    async move(direction) {
      if (!direction) {
        print(`Go where? Exits: ${state.exits.map((e) => e.direction).join(", ")}`, "error");
        return;
      }
      const result = await act("move", { direction });
      if (!result) return;
      if (!result.ok) {
        print(`${result.message} Exits: ${state.exits.map((e) => e.direction).join(", ")}`, "error");
        return;
      }
      print(result.message, "dim");
      describe();
    },

    async take(name) {
      const items = state.items;
      if (!items.length) {
        print("There's nothing here to pick up.", "error");
        return;
      }
      let matches = name ? items.filter((item) => item.name.toLowerCase().includes(name)) : items;
      const exact = matches.find((item) => item.name.toLowerCase() === name);
      if (exact) matches = [exact];
      if (!matches.length) {
        print(`You don't see "${name}" here.`, "error");
        return;
      }
      if (matches.length > 1) {
        print(`Which one? ${matches.map((item) => item.name).join(", ")}`, "error");
        return;
      }
      const result = await act("pickup", { item_id: matches[0].id });
      if (!result) return;
      print(result.message, result.ok ? "success" : "error");
      if (result.ok) print(matches[0].description, "dim");
      if (result.ok && state.mission.collected === state.mission.required) {
        print("That's every component. Return to the Crash Site and launch!", "banner");
      }
    },

    async inventory() {
      const result = await act("inventory");
      if (!result) return;
      print(result.message);
      state.inventory.forEach((item) => print(`  • ${item.name} — ${item.description}`, "dim"));
      print(`Components recovered: ${state.mission.collected}/${state.mission.required}`, "dim");
    },

    async launch() {
      const result = await act("complete");
      if (!result) return;
      if (!result.ok) {
        print(result.message, "error");
        (result.missing || []).forEach((item) => print(`  ✗ ${item.name}: ${item.hint}`, "dim"));
        return;
      }
      [
        "",
        "        /\\",
        "       /  \\        ENGINES ONLINE",
        "      |    |       NAV LOCKED",
        "      |    |       LAUNCH SEQUENCE COMPLETE",
        "     /|/\\/\\|\\",
        "      ''''''",
        "",
      ].forEach((line) => print(line, "banner"));
      print(result.message, "success");
      print(`Moves: ${result.stats.moves}   Mission time: ${formatDuration(result.stats.elapsed_seconds)}`, "dim");
      print("Type 'restart' to fly the mission again.", "dim");
    },

    async logEntries() {
      const { status, data } = await api("GET", `/api/players/${playerId}/log?limit=15`);
      if (status !== 200 || !Array.isArray(data)) {
        print("Could not read the action log.", "error");
        return;
      }
      renderLog(data.slice(0, 12));
      [...data].reverse().forEach((entry) =>
        print(`${new Date(entry.time).toLocaleTimeString()}  ${entry.action.padEnd(26)} ${entry.details || ""}`, "dim"));
    },

    async restart() {
      const result = await act("restart");
      if (!result) return;
      print(result.message, "success");
      describe();
    },

    clear() {
      output.replaceChildren();
    },

    logout() {
      logout();
    },
  };

  function toDirection(word) {
    return DIRECTION_ALIASES[word] || word;
  }

  async function run(text) {
    const words = text.toLowerCase().split(/\s+/);
    let [verb, ...rest] = words;
    if (verb === "pick" && rest[0] === "up") rest = rest.slice(1);
    const arg = rest.join(" ");

    switch (verb) {
      case "help": case "h": case "?": return commands.help();
      case "look": case "l": return commands.look();
      case "go": case "move": case "walk": case "head": return commands.move(toDirection(arg));
      case "take": case "get": case "grab": case "pick": return commands.take(arg);
      case "inventory": case "inv": case "i": return commands.inventory();
      case "launch": case "repair": case "complete": return commands.launch();
      case "log": case "history": return commands.logEntries();
      case "restart": return commands.restart();
      case "clear": case "cls": return commands.clear();
      case "logout": case "quit": return commands.logout();
    }

    // a bare direction, including any direction the current location offers
    const direction = toDirection(text.toLowerCase());
    if (DIRECTIONS.includes(direction) || state.exits.some((e) => e.direction === direction)) {
      return commands.move(direction);
    }
    print(`Unknown command "${text}". Type 'help' for a list of commands.`, "error");
  }

  async function submit(raw) {
    const text = raw.trim();
    if (!text || busy || !state) return;
    print(`> ${text}`, "cmd");
    history.push(text);
    historyIndex = history.length;
    busy = true;
    try {
      await run(text);
    } catch (error) {
      console.error(error);
      print("Lost contact with the ship's computer. Is the server running?", "error");
    } finally {
      busy = false;
      input.focus();
    }
  }

  /* ---------- session ---------- */

  function begin(id, nextState) {
    playerId = id;
    storage.set(String(id));
    render(nextState);
    input.disabled = false;
    input.focus();
    refreshLog();
  }

  function logout() {
    playerId = null;
    state = null;
    storage.clear();
    input.disabled = true;
    $("logout").hidden = true;
    output.replaceChildren();
    $("login-error").textContent = "";
    loginDialog.showModal();
  }

  $("login-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    const username = $("username").value.trim();
    if (!username) return;
    let response;
    try {
      response = await api("POST", "/api/players", { username });
    } catch {
      $("login-error").textContent = "Cannot reach the server.";
      return;
    }
    const { data } = response;
    if (!data || !data.ok) {
      $("login-error").textContent = (data && data.message) || "Something went wrong.";
      return;
    }
    loginDialog.close();
    output.replaceChildren();
    begin(data.state.player.id, data.state);
    if (data.is_new) {
      print("Alarms. Smoke. Then silence.", "banner");
      print("Your starship has crash-landed on an uncharted alien world. Four critical components were " +
        "thrown clear in the crash. Find them, return to the Crash Site and launch.");
      print("Type 'help' for a list of commands.", "dim");
    }
    print(data.message, "success");
    describe();
  });

  // the login dialog cannot be dismissed without a callsign
  loginDialog.addEventListener("cancel", (event) => event.preventDefault());

  $("prompt").addEventListener("submit", (event) => {
    event.preventDefault();
    const text = input.value;
    input.value = "";
    submit(text);
  });

  input.addEventListener("keydown", (event) => {
    if (event.key === "ArrowUp" && historyIndex > 0) {
      historyIndex -= 1;
    } else if (event.key === "ArrowDown" && historyIndex < history.length) {
      historyIndex += 1;
    } else {
      return;
    }
    event.preventDefault();
    input.value = history[historyIndex] || "";
  });

  document.querySelectorAll("[data-cmd]").forEach((button) =>
    button.addEventListener("click", () => submit(button.dataset.cmd)));
  $("logout").addEventListener("click", logout);

  // resume a saved session, otherwise ask for a callsign
  (async () => {
    const saved = Number(storage.get());
    if (saved > 0) {
      try {
        const { status, data } = await api("GET", `/api/players/${saved}`);
        if (status === 200 && data && data.state) {
          begin(saved, data.state);
          print(`Reconnected. Welcome back, Commander ${data.state.player.username}.`, "success");
          describe();
          return;
        }
      } catch { /* fall through to login */ }
    }
    logout();
  })();
})();
