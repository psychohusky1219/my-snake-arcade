import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

// Exercise the actual shipped inline engine. The fixture API is injected only
// into this VM copy; no debug hooks or test controls are exposed in the game.
const html = fs.readFileSync(fileURLToPath(new URL('../Web/index.html', import.meta.url)), 'utf8');
const script = html.match(/<script>\s*([\s\S]*?)<\/script>/)[1];
const fixtureScript = script.replace(/\}\)\(\);\s*$/, 'globalThis.fixture = source => eval(source);\n})();');

function session(saved = {}) {
  const storage = new Map(Object.entries(saved));
  const elements = new Map();
  const canvasContext = new Proxy({}, { get: (object, key) => object[key] ?? (() => {}), set: (object, key, value) => (object[key] = value, true) });
  function element(id) {
    if (!elements.has(id)) {
      const classes = new Set();
      const handlers = new Map();
      elements.set(id, {
        id, style: {}, dataset: {}, textContent: '', hidden: false, clientWidth: 480, clientHeight: 480,
        classList: { add: name => classes.add(name), remove: name => classes.delete(name), contains: name => classes.has(name), toggle: (name, on) => on ? classes.add(name) : classes.delete(name) },
        addEventListener: (name, fn) => handlers.set(name, fn),
        setAttribute(name, value) { this[name] = value; },
        getContext: () => canvasContext,
        getBoundingClientRect: () => ({ left: 0, top: 0, width: 300, height: 160 }),
        setPointerCapture() {}, hasPointerCapture: () => false,
        fire(name, extra = {}) { handlers.get(name)?.({ preventDefault() {}, detail: 0, ...extra }); },
        handlers
      });
    }
    return elements.get(id);
  }
  const arrows = ['up', 'down', 'left', 'right'].map(name => {
    const button = element(`arrow-${name}`); button.dataset.dir = name; return button;
  });
  let now = 0;
  let nextTimeout = 0;
  const timers = new Map();
  const document = { getElementById: element, querySelectorAll: () => arrows, addEventListener() {}, documentElement: {}, hidden: false };
  const context = vm.createContext({
    document, window: { addEventListener() {} }, navigator: {}, location: { protocol: 'http:' },
    localStorage: { getItem: key => storage.get(key) ?? null, setItem: (key, value) => storage.set(key, String(value)) },
    performance: { now: () => now },
    setTimeout: (fn, delay) => { const id = ++nextTimeout; timers.set(id, { fn, delay }); return id; },
    clearTimeout: id => timers.delete(id), console
  });
  vm.runInContext(fixtureScript, context, { filename: 'Web/index.html' });
  const run = source => context.fixture(source);
  const tick = () => { now += run('millis()'); run('tick()'); };
  return { run, tick, element, storage, timers };
}

let passed = 0;
function test(name, fn) {
  fn(); passed++;
  console.log(`PASS ${name}`);
}
const near = (actual, expected) => assert.ok(Math.abs(actual - expected) < 1e-9, `${actual} != ${expected}`);

for (const gameMode of ['classic', 'survivor', 'speedRun']) {
  test(`${gameMode}: rat multiplies current score and speed, preserves level/layout`, () => {
    const game = session();
    game.run(`selectGameMode('${gameMode}'); start(); snake=[{x:2,y:2},{x:1,y:2},{x:0,y:2}]; heading=direction.right; food={x:3,y:2,type:'rat'}; ratRemaining=8000; score=7n; apples=9; level=10n; speed=4; obstacles=[{x:20,y:20}]; obstacleSet=new Set([20*COUNT+20]);`);
    game.tick();
    assert.equal(game.run('score'), 35n);
    assert.equal(game.run('level'), 10n);
    assert.equal(game.run('apples'), 9);
    assert.equal(game.run('speed'), 20);
    assert.equal(game.run('snake.length'), 4);
    assert.equal(game.run('obstacles.length'), 1);
  });
  test(`${gameMode}: apple advances one level independently of multiplied score`, () => {
    const game = session();
    game.run(`selectGameMode('${gameMode}'); start(); snake=[{x:2,y:2},{x:1,y:2},{x:0,y:2}]; food={x:3,y:2,type:'apple'}; score=625n; apples=3; level=4n; speed=8;`);
    game.tick();
    assert.equal(game.run('score'), 626n);
    assert.equal(game.run('level'), 5n);
    near(game.run('speed'), 8 + 1000 / 210 * .055);
  });
}

test('rat speed cap and zero score are independent', () => {
  const game = session();
  game.run(`start(); snake=[{x:2,y:2},{x:1,y:2},{x:0,y:2}]; food={x:3,y:2,type:'rat'}; ratRemaining=8000; score=0n; speed=12;`);
  game.tick();
  assert.equal(game.run('score'), 0n);
  assert.equal(game.run('level'), 1n);
  assert.equal(game.run('speed'), 30);
  near(game.run('millis()'), 1000 / 30);
});

test('reset restores starting speed and separate progression', () => {
  const game = session();
  game.run('start(); speed=30; score=10000n; apples=7; level=8n; start();');
  assert.equal(game.run('score'), 0n);
  assert.equal(game.run('level'), 1n);
  near(game.run('millis()'), 210);
});

test('Classic records and touch controller survive startup', () => {
  const game = session({ 'my-private-snake-best-v1': '999999999999999999', 'my-snake-survivor-best-v1': '44', 'my-snake-control-mode-v1': 'touch' });
  assert.equal(game.run('best'), 999999999999999999n);
  assert.equal(game.run('controlMode'), 'touch');
  assert.equal(game.element('arrow-pad').hidden, true);
  assert.equal(game.element('touch-pad').hidden, false);
  game.run("selectGameMode('survivor')");
  assert.equal(game.run('best'), 44n);
  game.run("selectGameMode('classic')");
  assert.equal(game.run('best'), 999999999999999999n);
});

test('pause freezes movement and rat lifetime', () => {
  const game = session();
  game.run("start(); food={x:10,y:10,type:'rat'}; ratRemaining=7000; pause()");
  const before = game.run('JSON.stringify(snake)');
  game.tick();
  assert.equal(game.run('JSON.stringify(snake)'), before);
  assert.equal(game.run('ratRemaining'), 7000);
  assert.equal(game.run('mode'), 'paused');
});

test('wrapping and two-turn queue remain playable', () => {
  const game = session();
  game.run("start(); snake=[{x:23,y:5},{x:22,y:5},{x:21,y:5}]; food={x:10,y:10,type:'apple'}");
  game.tick();
  assert.equal(game.run('snake[0].x'), 0);
  game.run("turn('up');turn('left')");
  game.tick(); game.tick();
  assert.equal(game.run('snake[0].x'), 23);
  assert.equal(game.run('snake[0].y'), 4);
});

test('board has no swipe handlers; separate pad accepts gestures', () => {
  const game = session();
  assert.equal(game.element('canvas').handlers.has('pointerdown'), false);
  assert.equal(game.element('field').handlers.has('pointerdown'), false);
  assert.equal(game.element('touch-pad').handlers.has('pointerdown'), true);
});

test('four playable modes have the confirmed grid sizes and starting lengths', () => {
  const game = session();
  for (const [name, size, length] of [['classic',24,3],['survivor',34,3],['speedRun',42,3],['endless',24,5]]) {
    game.run(`mode='menu'; selectGameMode('${name}'); start()`);
    assert.equal(game.run('COUNT'), size);
    near(game.run('CELL'), 480 / size);
    assert.equal(game.run('snake.length'), length);
    assert.equal(game.run('mode'), 'running');
  }
});

test('Survivor probability starts at level 10 and reaches its cap at 29', () => {
  const game = session();
  for (const [level, expected] of [[1,0],[9,0],[10,.05],[11,.1],[28,.95],[29,1],[30,1],[1000000,1]]) {
    near(game.run(`obstacleChance(${level}n)`), expected);
  }
  assert.equal(game.run('obstacleChance(999999999999999999999999999999999999n)'), 1);
});

test('Survivor rolls use the exact probability boundary and clear previous layouts', () => {
  const game = session();
  game.run("selectGameMode('survivor');start();level=10n;refreshObstacles(()=>.049)");
  assert.ok(game.run('obstacles.length') > 0);
  game.run('refreshObstacles(()=>.05)');
  assert.equal(game.run('obstacles.length'), 0);
  game.run('level=29n;refreshObstacles(()=>.999)');
  assert.ok(game.run('obstacles.length') > 0);
  game.run('level=9n;refreshObstacles(()=>0)');
  assert.equal(game.run('obstacles.length'), 0);
});

test('seeded Survivor layouts protect food, snake, head space and connected paths', () => {
  const game = session();
  game.run("selectGameMode('survivor');start();level=29n");
  for (let seed = 1; seed <= 24; seed++) {
    game.run(`{let seed=${seed}; refreshObstacles(()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296})}`);
    assert.ok(game.run('obstacles.length') > 0);
    assert.equal(game.run('obstacles.some(p=>snake.some(s=>p.x===s.x&&p.y===s.y)||(food&&food.x===p.x&&food.y===p.y))'), false);
    assert.equal(game.run('openCellsConnected(obstacleSet,snake[0])'), true);
    assert.equal(game.run('obstacles.some(p=>{const h=snake[0];return Math.min(Math.abs(p.x-h.x),COUNT-Math.abs(p.x-h.x))+Math.min(Math.abs(p.y-h.y),COUNT-Math.abs(p.y-h.y))<=4})'), false);
  }
});

test('Survivor obstacle collision is fatal, including wrap crossings', () => {
  const game = session();
  game.run("selectGameMode('survivor');start();snake=[{x:33,y:5},{x:32,y:5},{x:31,y:5}];food={x:10,y:10,type:'apple'};obstacles=[{x:0,y:5}];obstacleSet=new Set([5*COUNT])");
  game.tick();
  assert.equal(game.run('mode'), 'over');
  assert.equal(game.run('collisionCause'), 'obstacle');
});

test('rat eligibility is three apples and Speed Run uses a higher chance', () => {
  const game = session();
  game.run("start();apples=2;Math.random=()=>0;nextFood()");
  assert.equal(game.run('food.type'), 'apple');
  game.run('apples=3;Math.random=()=>.179;nextFood()');
  assert.equal(game.run('food.type'), 'rat');
  game.run('Math.random=()=>.18;nextFood()');
  assert.equal(game.run('food.type'), 'apple');
  game.run("mode='menu';selectGameMode('speedRun');start();apples=3;Math.random=()=>.449;nextFood()");
  assert.equal(game.run('food.type'), 'rat');
  game.run('Math.random=()=>.45;nextFood()');
  assert.equal(game.run('food.type'), 'apple');
});

test('rat expiry becomes an apple in the same safe cell', () => {
  const game = session();
  game.run("start();food={x:0,y:0,type:'rat'};ratRemaining=1");
  game.tick();
  assert.equal(game.run("JSON.stringify(food)"), '{"x":0,"y":0,"type":"apple"}');
});

test('new-mode scores are separate and existing records remain untouched', () => {
  const game = session({ 'my-private-snake-best-v1':'100','my-snake-survivor-best-v1':'200' });
  for (const [name, points] of [['speedRun',30],['endless',40]]) {
    game.run(`mode='menu';selectGameMode('${name}');score=${points}n;saveBest()`);
    assert.equal(game.storage.get(`my-snake-${name}-best-v1`), String(points));
  }
  assert.equal(game.storage.get('my-private-snake-best-v1'), '100');
  assert.equal(game.storage.get('my-snake-survivor-best-v1'), '200');
});

test('Endless camera, scrolling and steering keep the head anchored', () => {
  const game = session();
  game.run("selectGameMode('endless');start();endlessFoods=[];obstacles=[{x:0,y:0}];turn('left')");
  const headX = game.run('snake[0].x');
  const headY = game.run('snake[0].y');
  game.tick();
  assert.equal(game.run('snake[0].x'), headX-1);
  assert.equal(game.run('snake[0].y'), headY);
  assert.equal(game.run('snake[1].y'), headY+1);
  assert.equal(game.run('obstacles[0].y'), 1);
  assert.equal(game.run('scrollRows'), 1);
  game.run("turn('down')");game.tick();
  assert.equal(game.run('snake[0].x'), headX-1);
  assert.equal(game.run('snake[0].y'), headY);
});

for (const foodType of ['apple','rat']) {
  test(`Endless ${foodType} adds exactly one segment and one point`, () => {
    const game = session();
    game.run(`selectGameMode('endless');start();score=7n;endlessFoods=[{x:snake[0].x,y:snake[0].y-1,type:'${foodType}'}]`);
    game.tick();
    assert.equal(game.run('snake.length'), 6);
    assert.equal(game.run('score'), 8n);
    near(game.run('speed'), foodType==='rat'?5.36:5.12);
  });
}

test('Endless obstacle group removes one segment and cannot damage again', () => {
  const game = session();
  game.run("selectGameMode('endless');start();endlessFoods=[];obstacles=[-1,0,1].map(i=>({x:snake[0].x+i,y:snake[0].y-1}))");
  game.tick();
  assert.equal(game.run('snake.length'), 4);
  assert.equal(game.run('obstacles.length'), 0);
  for (let i=0;i<4;i++) game.tick();
  assert.equal(game.run('snake.length'), 4);
  assert.equal(game.run('mode'), 'running');
  game.run('obstacles=[{x:snake[0].x,y:snake[0].y-1}]');game.tick();
  assert.equal(game.run('snake.length'), 3);
});

test('Endless tail contact is harmless and offscreen tail remains health', () => {
  const game = session();
  game.run("selectGameMode('endless');start();endlessFoods=[];snake=Array.from({length:30},(_,i)=>({x:12,y:15+i}));obstacles=[{x:12,y:16}]");
  game.tick();
  assert.equal(game.run('snake.length'), 30);
  assert.equal(game.run('mode'), 'running');
});

test('Endless dies at zero and never runs another tick', () => {
  const game = session();
  game.run("selectGameMode('endless');start();endlessFoods=[];snake=[snake[0]];obstacles=[{x:snake[0].x,y:snake[0].y-1}]");
  game.tick();
  assert.equal(game.run('snake.length'), 0);
  assert.equal(game.run('mode'), 'over');
  const rows=game.run('scrollRows');game.tick();
  assert.equal(game.run('scrollRows'), rows);
});

test('Endless artificial simultaneous food and damage grows before damage', () => {
  const game = session();
  game.run("selectGameMode('endless');start();snake=[snake[0]];endlessFoods=[{x:snake[0].x,y:snake[0].y-1,type:'rat'}];obstacles=[{x:snake[0].x,y:snake[0].y-1}]");
  game.tick();
  assert.equal(game.run('snake.length'), 1);
  assert.equal(game.run('score'), 1n);
  assert.equal(game.run('mode'), 'running');
});

test('Endless clamps side edges and ignores self contact', () => {
  const game = session();
  game.run("selectGameMode('endless');start();snake=[{x:0,y:15},{x:0,y:14},{x:0,y:13}];endlessFoods=[];turn('left')");
  game.tick();
  assert.equal(game.run('snake[0].x'), 0);
  assert.equal(game.run('mode'), 'running');
  assert.equal(game.run('snake.length'), 3);
});

test('Endless spawn cadence leaves gaps and never overlaps food', () => {
  const game = session();
  game.run("selectGameMode('endless');start();endlessFoods=[];scrollRows=5;spawnEndless(()=>0)");
  assert.equal(game.run('obstacles.length'), 0);
  game.run('scrollRows=10;spawnEndless(()=>.999)');
  assert.equal(game.run('obstacles.length'), 3);
  game.run('scrollRows=20;obstacles=[];spawnEndless(()=>0)');
  assert.equal(game.run('endlessFoods.length'), 1);
  assert.equal(game.run('obstacles.length'), 1);
  assert.equal(game.run('endlessFoods.some(f=>obstacles.some(o=>o.x===f.x&&o.y===f.y))'), false);
});

test('Endless cleans offscreen scenery, freezes while paused and fully resets', () => {
  const game = session();
  game.run("selectGameMode('endless');start();endlessFoods=[{x:0,y:23,type:'rat'}];obstacles=[{x:1,y:23}];turn('right');pause()");
  game.tick();
  assert.equal(game.run('scrollRows'), 0);
  assert.equal(game.run('obstacles[0].y'), 23);
  game.run('pause()');game.tick();
  assert.equal(game.run('obstacles.length'), 0);
  assert.equal(game.run('endlessFoods.length'), 0);
  game.run('start()');
  assert.equal(game.run('scrollRows'), 0);
  assert.equal(game.run('endlessSteer'), 0);
  assert.equal(game.run('snake.length'), 5);
  assert.equal(game.run('speed'), 5);
});

test('Endless gradual acceleration stops at the shared responsiveness cap', () => {
  const game = session();
  game.run("selectGameMode('endless');start();speed=29.9;endlessFoods=[{x:snake[0].x,y:snake[0].y-1,type:'rat'}]");
  game.tick();
  assert.equal(game.run('speed'), 30);
});

{
  const worker = fs.readFileSync(fileURLToPath(new URL('../Web/sw.js', import.meta.url)), 'utf8');
  const handlers = new Map();
  const cacheData = new Map([['my-snake-survivor-v4',new Map()],['unrelated-cache',new Map()]]);
  const caches = {
    async open(name) {
      if (!cacheData.has(name)) cacheData.set(name, new Map());
      const data=cacheData.get(name);
      return { async addAll(paths) { for(const path of paths)data.set(path,{cached:path}); }, async put(path,response) { data.set(path,response); } };
    },
    async keys() { return [...cacheData.keys()]; },
    async delete(name) { return cacheData.delete(name); },
    async match(request) { for(const data of cacheData.values()){const value=data.get(typeof request==='string'?request:request.url);if(value)return value;} }
  };
  const context = vm.createContext({ caches, URL, fetch: async () => { throw new Error('offline'); }, self: {
    location:{origin:'https://snake.test'}, addEventListener:(name,fn)=>handlers.set(name,fn),
    skipWaiting:async()=>{}, clients:{claim:async()=>{}}
  }});
  vm.runInContext(worker, context, {filename:'Web/sw.js'});
  let pending;
  handlers.get('install')({waitUntil:value=>{pending=value}});await pending;
  handlers.get('activate')({waitUntil:value=>{pending=value}});await pending;
  assert.equal(cacheData.has('my-snake-survivor-v4'),false);
  assert.equal(cacheData.has('unrelated-cache'),true);
  assert.ok(cacheData.get('my-snake-four-modes-v5').has('./index.html'));
  handlers.get('fetch')({request:{method:'GET',url:'https://snake.test/?source=homescreen',mode:'navigate'},respondWith:value=>{pending=value}});
  assert.equal((await pending).cached,'./index.html');
  passed++;console.log('PASS service worker upgrades its own cache and serves the game offline');
}

console.log(`\n${passed} browser behavior groups passed.`);
