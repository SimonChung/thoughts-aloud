// Each desktop frame is navigable. They share the cards for this preview session.
(() => {
  'use strict';

  const cards = [
    { id: 'walk', title: '把散步留在行事曆裡', date: '2026-11-26T09:12:00', seconds: 42, topic: '生活', art: 'sunset', saved: false,
      text: '今天提早一站下車，慢慢走到公司。原來只要多出十分鐘，就能注意到路口那棵樹換了顏色。\n\n下週試著把散步也排進行事曆。' },
    { id: 'idea', title: '好點子需要一點空白', date: '2026-11-25T17:35:00', seconds: 68, topic: '靈感', art: 'ripple', saved: true,
      text: '有時候，最好的點子出現在什麼都沒做的時候。想替每天下午留一小段空白，看看會冒出什麼念頭。' },
    { id: 'meeting', title: '下次開會，先留三分鐘', date: '2026-11-24T13:40:00', seconds: 36, topic: '工作', art: 'steps', saved: false,
      text: '下次討論前，先讓每個人安靜寫三分鐘，再輪流說出想法。也許平常比較安靜的人會有更多空間。' },
    { id: 'morning', title: '早晨的小小儀式', date: '2026-11-23T07:48:00', seconds: 54, topic: '生活', art: 'blush', saved: false,
      text: '水煮開以前，到陽台站一會兒。早上的第一件事，可以只是看著天慢慢亮起來。' },
  ];
  const script = ['剛才走過巷口的時候，', '聽見有人在練琴。', '有些日常的小聲音，', '也值得專程停下來聽。'];
  const iconPaths = {
    search: 'M16 16l5 5 M18 10.5a7.5 7.5 0 1 1-15 0 7.5 7.5 0 1 1 15 0',
    mic: 'M9 10V6a3 3 0 0 1 6 0v4a3 3 0 0 1-6 0 M5.5 10a6.5 6.5 0 0 0 13 0 M12 17v4 M9 21h6',
    bookmark: 'M6.5 4.5a1 1 0 0 1 1-1h9a1 1 0 0 1 1 1v16l-5.5-3.8-5.5 3.8z',
    back: 'M19 12H5 M11 6l-6 6 6 6', next: 'M9 6l6 6-6 6', close: 'M6 6l12 12 M18 6L6 18',
    play: 'M8 4.5l12 7.5-12 7.5z', pause: 'M8 5v14 M16 5v14', stop: 'M6 6h12v12H6z',
    check: 'M4 12l5.5 5.5L20 7', text: 'M4 6h16 M4 12h12 M4 18h9',
  };
  const shortDate = new Intl.DateTimeFormat('zh-TW', {month:'numeric', day:'numeric'});
  const fullDate = new Intl.DateTimeFormat('zh-TW', {year:'numeric', month:'long', day:'numeric'});
  const time = new Intl.DateTimeFormat('zh-TW', {hour:'2-digit', minute:'2-digit', hourCycle:'h23'});
  const wide = matchMedia('(min-width:1100px)');
  const reduced = matchMedia('(prefers-reduced-motion:reduce)');
  const panels = [];
  let serial = 0;
  const escape = value => String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const icon = (name, size = 20, fill = false) => `<canvas class="icon" data-icon="${name}" data-size="${size}" data-fill="${fill}" style="width:${size}px;height:${size}px" aria-hidden="true"></canvas>`;
  const clock = seconds => [Math.floor(seconds / 60), seconds % 60].map(n => String(n).padStart(2,'0')).join(':');
  const getCard = id => cards.find(card => card.id === id);
  const btn = (action, name, symbol, extra = '') => `<button class="icon-button ${extra}" data-action="${action}" aria-label="${escape(name)}" title="${escape(name)}">${icon(symbol)}</button>`;
  const art = (card, size) => `<span aria-hidden="true" class="art ${size} ${card.art}"></span>`;
  const head = (name, action = 'back', last = '<span class="balance"></span>') => `<header class="topbar">${btn(action,'返回','back')}<span class="nav-title">${name}</span>${last}</header>`;
  function cardRow(card) {
    const date = new Date(card.date);
    return `<button class="card-row" data-action="open" data-id="${card.id}">${art(card,'thumb')}
      <span class="row-copy"><span class="row-title">${escape(card.title)}</span><span class="meta">${shortDate.format(date)}<span aria-hidden="true">·</span><span class="duration">${clock(card.seconds)}</span>${card.saved ? icon('bookmark',12,true) : ''}</span></span><span class="arrow">${icon('next',16)}</span></button>`;
  }
  function libraryResults(p) {
    const query = p.query.trim().toLocaleLowerCase();
    const results = cards.filter(c => (!p.savedOnly || c.saved) && (!query || (c.title + c.topic + c.text).toLocaleLowerCase().includes(query)));
    return results.length ? results.map(cardRow).join('') : `<p class="empty">${query ? '找不到符合的卡片，試試其他關鍵字。' : '還沒有收藏。打開卡片，點一下書籤就能在這裡找到它。'}</p>`;
  }
  function library(p) {
    const logo = '<span class="logo" aria-hidden="true"><i></i><i></i><i></i><i></i><i></i></span>';
    return `<header class="topbar"><div class="home-brand">${logo}<div><strong>想唸</strong><small lang="en">Thoughts Aloud</small></div></div>${btn('search','搜尋卡片','search')}</header>
      <div class="scroll content"><div class="hero"><h1>把想法<br>說下來。</h1>
        <div class="cassette" aria-hidden="true"><div class="tape-label"><div class="window"><i class="reel"></i><i class="reel"></i></div></div><i class="tape-base"></i></div>
        <button class="cta" data-action="record">${icon('mic',18)}開始錄音</button></div>
        <div class="section-head"><h2>我的卡片匣</h2><span class="count">${cards.length} 張卡片</span></div>
        <div class="filters" aria-label="卡片篩選"><button class="filter" data-action="all" aria-pressed="${!p.savedOnly}"><span>全部</span></button>
        <button class="filter" data-action="saved" aria-pressed="${p.savedOnly}"><span>${icon('bookmark',13)}收藏</span></button></div>
        ${p.search ? `<div class="search-line"><input class="field" aria-label="搜尋卡片" name="query" type="search" placeholder="搜尋標題或逐字稿" value="${escape(p.query)}">${btn('hide-search','關閉搜尋','close')}</div>` : ''}
        <div class="results">${libraryResults(p)}</div></div>`;
  }
  function recording(p) {
    return `${head('語音卡片','leave-studio')}
      <div class="scroll content studio-content"><h1 class="screen-title">錄音室</h1>
        <div class="deck ${p.running ? '' : 'paused'}"><div class="deck-head"><span class="lamp"></span><span class="demo">示範模式</span></div>
        <div class="clock"></div><canvas class="wave signal" height="78" style="height:78px" aria-hidden="true"></canvas>
        <div class="scale" aria-hidden="true"><span>−6 s</span><span>−3 s</span><span>現在</span></div></div>
        <div class="section-head"><h2>即時逐字稿</h2>${icon('text',18)}</div>
        <div class="live-text"><span class="words"></span><i class="cursor" aria-hidden="true"></i></div>
        <p class="record-note">此處以範例文字示範錄音流程。</p></div>
      <footer class="transport"><button class="secondary" data-action="toggle-record">${icon(p.running ? 'pause' : 'mic',17)}${p.running ? '暫停' : '繼續'}</button>
        <button class="primary" data-action="finish">${icon('stop',14,true)}完成錄音</button></footer>`;
  }
  function detail(p) {
    const card = getCard(p.id);
    const date = new Date(card.date);
    const related = cards.filter(c => c.id !== card.id && c.topic === card.topic).slice(0,2);
    const save = `<button class="icon-button ${card.saved ? 'filled' : ''}" data-action="bookmark" aria-label="${card.saved ? '取消收藏' : '加入收藏'}" aria-pressed="${card.saved}" title="${card.saved ? '取消收藏' : '加入收藏'}">${icon('bookmark',20,card.saved)}</button>`;
    return `${head('語音卡片','back',save)}<div class="scroll content detail-content">${art(card,'cover')}
      <h1 class="screen-title detail-title">${escape(card.title)}</h1>
      <div class="meta detail-meta">${fullDate.format(date)}<span aria-hidden="true">·</span>${time.format(date)}<span class="tag">${card.topic}</span></div>
      <div class="player"><button class="icon-button play" data-action="play" aria-label="${p.playing ? '暫停播放示範' : '播放進度示範'}">${icon(p.playing ? 'pause' : 'play',18,!p.playing)}</button>
        <div class="audio-track"><canvas class="wave progress-wave" aria-hidden="true"></canvas><div class="play-meta"><span>播放進度示範</span><span class="duration play-time"></span></div></div></div>
      <div class="section-head"><h2>逐字稿</h2></div><p class="transcript">${escape(card.text)}</p>
      <div class="section-head"><h2>相關卡片</h2></div><div class="related-list">${related.length ? related.map(cardRow).join('') : '<p class="subtle">目前沒有相同主題的卡片。</p>'}</div></div>`;
  }
  function edit(p) {
    return `${head('錄音室','resume-edit')}<div class="scroll content"><h1 class="screen-title">整理語音卡片</h1>
      <p class="status">示範錄音 · ${clock(p.elapsed)} · 僅保留在本次預覽</p>
      <form class="edit-form"><label for="title-${p.root.id}">卡片標題</label><input class="field" id="title-${p.root.id}" name="title" required maxlength="100" value="${escape(p.draftTitle)}">
      <label for="text-${p.root.id}">逐字稿</label><textarea class="field" id="text-${p.root.id}" name="text" required>${escape(p.draftText)}</textarea>
      <button class="primary" type="submit">${icon('check',18)}儲存卡片</button></form></div>`;
  }
  function discard() {
    return `${head('錄音室','return-studio')}<div class="scroll content"><h1 class="screen-title">離開這段錄音？</h1>
      <p class="status">這段示範錄音尚未存成卡片。</p><div class="edit-actions"><button class="secondary" data-action="discard">捨棄錄音</button><button class="primary" data-action="return-studio">保留錄音</button></div></div>`;
  }
  const views = {library,recording,detail,edit,discard};
  function canvasContext(canvas, width, height) {
    const ratio = window.devicePixelRatio || 1;
    const w = Math.max(1,Math.round(width * ratio));
    const h = Math.max(1,Math.round(height * ratio));
    if (canvas.width !== w || canvas.height !== h) { canvas.width = w; canvas.height = h; }
    const ctx = canvas.getContext('2d');
    ctx.setTransform(ratio,0,0,ratio,0,0);
    ctx.clearRect(0,0,width,height);
    return ctx;
  }
  function drawIcons(root) {
    root.querySelectorAll('canvas[data-icon]').forEach(canvas => {
      const {size,icon:name,fill} = canvas.dataset;
      const ctx = canvasContext(canvas,+size,+size);
      ctx.scale(size/24,size/24);
      ctx.lineWidth = name === 'pause' ? 3.4 : 1.8;
      ctx.lineCap = ctx.lineJoin = 'round';
      ctx.fillStyle = ctx.strokeStyle = getComputedStyle(canvas).color;
      const path = new Path2D(iconPaths[name]);
      if (fill === 'true') ctx.fill(path);
      ctx.stroke(path);
    });
  }
  function drawWave(canvas, phase, studio, progress) {
    const {width,height} = canvas.getBoundingClientRect();
    if (!width) return;
    const ctx = canvasContext(canvas,width,height);
    const step = studio ? 4.4 : 3.4;
    if (studio) {
      ctx.fillStyle = '#657b66';
      ctx.fillRect(0,height/2,width,.6);
    }
    const count = Math.floor(width/step);
    for (let i = 0; i < count; i++) {
      const n = i+phase;
      const envelope = .24 + .76*Math.abs(Math.sin(n*.106)*Math.cos(n*.049));
      const peak = .13 + .87*Math.abs(Math.sin(n*1.77)*Math.cos(n*.49));
      const bar = Math.max(2,height*envelope*peak);
      ctx.fillStyle = studio ? '#d6e79e' : (i/count < progress ? '#254a3d' : '#879878');
      ctx.fillRect(i*step, (height-bar)/2, studio ? 2.8 : 2, bar);
    }
  }
  const transcriptAt = seconds => script.slice(0, Math.min(script.length, 1 + Math.floor(seconds / 6))).join('');
  function updateMedia(p) {
    if (p.screen === 'recording') {
      p.root.querySelector('.lamp').textContent = p.running ? '錄音中' : '已暫停';
      p.root.querySelector('.clock').textContent = clock(p.elapsed);
      p.root.querySelector('.words').textContent = transcriptAt(p.elapsed);
      drawWave(p.root.querySelector('.signal'), reduced.matches ? 8 : p.elapsed * 1.7,true,0);
    } else if (p.screen === 'detail') {
      const duration = getCard(p.id).seconds;
      p.root.querySelector('.play-time').textContent = clock(p.position) + ' / ' + clock(duration);
      drawWave(p.root.querySelector('.progress-wave'),4,false,p.position/duration);
    }
  }
  function render(p, focus) {
    p.root.innerHTML = views[p.screen](p);
    drawIcons(p.root);
    updateMedia(p);
    const target = focus && p.root.querySelector(focus);
    if (target) {
      if (target.matches('h1')) target.tabIndex = -1;
      target.focus({preventScroll:!target.matches('input')});
    }
  }
  function reset(p) {
    p.stack = []; p.position = 0; p.playing = false;
    p.running = false; p.screen = 'library';
    render(p,'h1');
  }
  function openCard(p,id) {
    p.stack.push(p.screen === 'detail' ? p.id : null);
    p.screen = 'detail'; p.id = id; p.playing = false; p.position = 0;
    render(p,'h1');
  }
  function refreshOthers(p) {
    panels.filter(other => other !== p && ['library','detail'].includes(other.screen)).forEach(other => {
      const scroll = other.root.querySelector('.scroll').scrollTop;
      const active = other.root.contains(document.activeElement) ? document.activeElement : null;
      const focus = active?.name === 'query' ? '[name=query]' : undefined;
      render(other,focus);
      other.root.querySelector('.scroll').scrollTop = scroll;
    });
  }
  function action(p, button) {
    const name = button.dataset.action;
    switch (name) {
      case 'record':
        p.screen = 'recording'; p.running = true; p.elapsed = 0; p.draftTitle = null; p.draftText = null; p.editedText = false; render(p,'h1'); break;
      case 'leave-studio':
        p.wasRunning = p.running; p.running = false; p.screen = 'discard'; render(p,'h1'); break;
      case 'discard': reset(p); break;
      case 'return-studio':
        p.running = p.wasRunning; p.screen = 'recording'; render(p,'h1'); break;
      case 'toggle-record':
        p.running = !p.running; render(p,'[data-action="toggle-record"]'); break;
      case 'finish':
        p.running = false; p.screen = 'edit'; p.draftTitle ??= '巷口的琴聲';
        if (!p.editedText) p.draftText = transcriptAt(p.elapsed);
        render(p,'h1'); break;
      case 'resume-edit':
        p.screen = 'recording'; render(p,'h1'); break;
      case 'search':
        p.search = true; render(p,'[name=query]'); break;
      case 'hide-search':
        p.search = false; p.query = ''; render(p,'[data-action=search]'); break;
      case 'all': case 'saved':
        p.savedOnly = name === 'saved'; render(p,`[data-action="${name}"]`); break;
      case 'open': openCard(p,button.dataset.id); break;
      case 'bookmark': {
        const card = getCard(p.id);
        card.saved = !card.saved;
        render(p,'[data-action=bookmark]'); refreshOthers(p); break;
      }
      case 'back': {
        const id = p.stack.pop();
        if (!id) { reset(p); break; }
        p.id = id; p.playing = false; p.position = 0; render(p,'h1'); break;
      }
      case 'play':
        if (p.position >= getCard(p.id).seconds) p.position = 0;
        p.playing = !p.playing; render(p,'[data-action=play]'); break;
    }
  }
  function attach(root,screen) {
    const p = {root,screen,stack:[],id:'walk',savedOnly:false,query:'',search:false,running:screen === 'recording',elapsed:12,playing:false,position:0};
    panels.push(p);
    root.addEventListener('click', e => { const button = e.target.closest('[data-action]'); if (button) action(p,button); });
    root.addEventListener('input', e => {
      if (e.target.name === 'query') {
        p.query = e.target.value;
        const results = root.querySelector('.results'); results.innerHTML = libraryResults(p); drawIcons(results);
      } else if (e.target.name === 'title') p.draftTitle = e.target.value;
      else if (e.target.name === 'text') { p.draftText = e.target.value; p.editedText = true; }
    });
    root.addEventListener('submit', e => {
      e.preventDefault();
      const form = e.target;
      for (const field of [form.elements.title,form.elements.text]) {
        if (!field.value.trim()) { field.setCustomValidity('請填寫內容。'); field.reportValidity(); field.setCustomValidity(''); return; }
      }
      const id = 'sample-' + ++serial;
      cards.unshift({id,title:p.draftTitle.trim(),text:p.draftText.trim(),topic:'生活',art:'ripple',date:new Date(),seconds:Math.max(1,p.elapsed),saved:false});
      p.savedOnly = false; p.search = false; p.query = ''; p.stack = [];
      openCard(p,id); refreshOthers(p);
    });
    render(p);
  }
  attach(document.querySelector('#library'),'library');
  attach(document.querySelector('#studio'),'recording');
  attach(document.querySelector('#reader'),'detail');
  const observer = new ResizeObserver(entries => {
    for (const entry of entries) {
      const p = panels.find(panel => panel.root === entry.target);
      updateMedia(p);
    }
  });
  panels.forEach(p => observer.observe(p.root));
  window.setInterval(() => {
    if (document.hidden) return;
    for (const p of panels) {
      if (p.root.classList.contains('companion') && !wide.matches) continue;
      if (p.screen === 'recording' && p.running) {
        p.elapsed++;
        updateMedia(p);
      } else if (p.screen === 'detail' && p.playing) {
        p.position++;
        if (p.position >= getCard(p.id).seconds) {
          p.playing = false;
          const focus = p.root.querySelector('[data-action=play]') === document.activeElement;
          render(p,focus ? '[data-action=play]' : undefined);
        }
        else updateMedia(p);
      }
    }
  },1000);
})();
