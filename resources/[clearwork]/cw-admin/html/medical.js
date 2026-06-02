(function () {
  function resourcePost(name, data) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {})
    });
  }

  function injectStyle() {
    if (document.getElementById('medicalAdminStyle')) return;

    const style = document.createElement('style');
    style.id = 'medicalAdminStyle';
    style.textContent = `
      .medical-admin-panel {
        margin: 12px 0 16px;
        padding: 14px;
        border: 1px solid rgba(255,255,255,.12);
        border-radius: 12px;
        background: rgba(255,255,255,.045);
      }
      .medical-admin-panel h3 { margin: 0 0 10px; }
      .medical-row { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }
      .medical-row input[type="number"] { width: 84px; }
      .medical-row input[type="range"] { width: 220px; }
      .medical-note { margin-top: 8px; opacity: .75; font-size: 12px; }
      .medical-revive-btn {
        background: rgba(50, 180, 90, .18) !important;
        border-color: rgba(50, 180, 90, .45) !important;
      }
      .medical-revive-btn:disabled {
        opacity: .55 !important;
        cursor: not-allowed !important;
      }
      .medical-dead-mark {
        display: inline-block;
        margin-top: 8px;
        padding: 4px 8px;
        border-radius: 999px;
        color: #ffd1d1;
        background: rgba(170, 20, 20, .25);
        border: 1px solid rgba(255, 80, 80, .25);
        font-size: 12px;
      }
    `;
    document.head.appendChild(style);
  }

  function getState() {
    if (window.State) return window.State;
    try {
      if (State) return State;
    } catch (_) {}
    return null;
  }

  function getPlayerFromState(source) {
    const state = getState();
    if (!state || !Array.isArray(state.players)) return null;
    return state.players.find((player) => Number(player.source) === Number(source)) || null;
  }

  function injectCharacterSettingsPanel() {
    const view = document.getElementById('view-characters');
    if (!view || document.getElementById('medicalSettingsPanel')) return;

    const searchRow = view.querySelector('.search-row');
    const panel = document.createElement('div');
    panel.id = 'medicalSettingsPanel';
    panel.className = 'medical-admin-panel';
    panel.innerHTML = `
      <h3>Перманентная смерть</h3>
      <div class="medical-row">
        <label for="medicalChanceRange">Шанс смерти:</label>
        <input id="medicalChanceRange" type="range" min="0" max="100" value="15">
        <input id="medicalChanceInput" type="number" min="0" max="100" value="15">
        <span>%</span>
        <button id="medicalChanceSave" type="button">Сохранить</button>
        <button id="medicalChanceRefresh" type="button">Обновить</button>
      </div>
      <div id="medicalChanceStatus" class="medical-note">Настройка применяется к новой рулетке при нокдауне.</div>
    `;

    if (searchRow) {
      view.insertBefore(panel, searchRow);
    } else {
      view.prepend(panel);
    }

    const range = document.getElementById('medicalChanceRange');
    const input = document.getElementById('medicalChanceInput');
    const save = document.getElementById('medicalChanceSave');
    const refresh = document.getElementById('medicalChanceRefresh');

    function syncFromRange() {
      input.value = range.value;
    }

    function syncFromInput() {
      let value = Number(input.value) || 0;
      value = Math.max(0, Math.min(100, Math.floor(value)));
      input.value = value;
      range.value = value;
    }

    range.addEventListener('input', syncFromRange);
    input.addEventListener('input', syncFromInput);
    save.addEventListener('click', () => {
      syncFromInput();
      resourcePost('medicalSetPermadeathChance', { chance: Number(input.value) });
    });
    refresh.addEventListener('click', () => resourcePost('medicalGetSettings'));

    resourcePost('medicalGetSettings');
  }

  function addReviveButtonsToPlayers() {
    const list = document.getElementById('playerList');
    if (!list) return;

    const cards = list.querySelectorAll('.player-card');
    cards.forEach((card) => {
      if (card.querySelector('[data-medical-revive-player]')) return;

      const title = card.querySelector('h3');
      const actions = card.querySelector('.player-actions');
      if (!title || !actions) return;

      const match = title.textContent.match(/^\[(\d+)\]/);
      if (!match) return;

      const source = Number(match[1]);
      const player = getPlayerFromState(source);
      const isPermadead = Number(player?.character?.is_dead || 0) === 1;

      const button = document.createElement('button');
      button.textContent = isPermadead ? 'Пермакилл' : 'Возродить';
      button.className = 'medical-revive-btn';
      button.dataset.medicalRevivePlayer = String(source);
      button.disabled = isPermadead;
      button.title = isPermadead
        ? 'Нельзя возродить через Игроки. Сначала сними пермакилл во вкладке Персонажи.'
        : 'Возродить игрока на текущем персонаже и текущем месте.';

      button.addEventListener('click', () => {
        if (button.disabled) return;
        resourcePost('medicalRevivePlayer', { source });
      });

      actions.appendChild(button);
    });
  }

  function addReviveButtonsToCharacters() {
    const state = getState();
    const list = document.getElementById('characterList');
    if (!state || !Array.isArray(state.characters) || !list) return;

    const cards = list.querySelectorAll('.character-card');
    cards.forEach((card, index) => {
      const character = state.characters[index];
      if (!character) return;

      const isDead = Number(character.is_dead) === 1;

      if (isDead && !card.querySelector('.medical-dead-mark')) {
        const mark = document.createElement('div');
        mark.className = 'medical-dead-mark';
        mark.textContent = 'Перма-килл';
        card.appendChild(mark);
      }

      if (!isDead || card.querySelector('[data-medical-revive-character]')) return;

      const actions = card.querySelector('.character-actions') || card;
      const button = document.createElement('button');
      button.textContent = 'Снять пермакилл / оживить';
      button.className = 'medical-revive-btn';
      button.dataset.medicalReviveCharacter = String(character.id);
      button.title = 'Снимает is_dead у персонажа. Если игрок онлайн на этом персонаже — возрождает его на месте.';

      button.addEventListener('click', () => {
        resourcePost('medicalReviveCharacter', { id: character.id });
        setTimeout(() => {
          const search = document.getElementById('searchBtn');
          if (search) search.click();
        }, 700);
      });

      actions.appendChild(button);
    });
  }

  function watchLists() {
    const playerList = document.getElementById('playerList');
    const characterList = document.getElementById('characterList');

    if (playerList && !playerList.dataset.medicalWatch) {
      playerList.dataset.medicalWatch = '1';
      new MutationObserver(() => setTimeout(addReviveButtonsToPlayers, 0))
        .observe(playerList, { childList: true, subtree: true });
    }

    if (characterList && !characterList.dataset.medicalWatch) {
      characterList.dataset.medicalWatch = '1';
      new MutationObserver(() => setTimeout(addReviveButtonsToCharacters, 0))
        .observe(characterList, { childList: true, subtree: true });
    }
  }

  function applySettings(payload) {
    payload = payload || {};

    const value = Number(payload.permadeathChance);
    const chance = Number.isFinite(value) ? value : 15;
    const range = document.getElementById('medicalChanceRange');
    const input = document.getElementById('medicalChanceInput');
    const status = document.getElementById('medicalChanceStatus');

    if (range) range.value = chance;
    if (input) input.value = chance;
    if (status) status.textContent = `Текущий шанс перманентной смерти: ${chance}%.`;
  }

  function init() {
    injectStyle();
    injectCharacterSettingsPanel();
    watchLists();
    setTimeout(addReviveButtonsToPlayers, 0);
    setTimeout(addReviveButtonsToCharacters, 0);
  }

  window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'medical:settings') applySettings(data.payload);

    if (
      data.action === 'characters:set' ||
      data.action === 'players:set' ||
      data.action === 'setVisible' ||
      data.action === 'open' ||
      data.action === 'panel:open'
    ) {
      setTimeout(init, 50);
    }
  });

  document.addEventListener('DOMContentLoaded', init);
  setTimeout(init, 500);
})();
