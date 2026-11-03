const fs = require('fs');
const vm = require('vm');
const assert = require('assert');
const source = fs.readFileSync('experiments/chams/menu.js', 'utf8');

function create(backend = true, failSet = false) {
    let next = 16, nodes = new Map(), timers = new Map(), calls = [], logs = [];
    function alloc(type) { let p = '0x' + (next++).toString(16); nodes.set(p, {type, children: [], tag: 0, on: false}); return p; }
    const win = alloc('window'), app = alloc('app');
    function msg(p, s, a) {
        const n = nodes.get(p); if (!n) throw Error('bad receiver ' + p + ' ' + s);
        if (s === 'sharedApplication') return app;
        if (s === 'keyWindow') return win;
        if (s === 'alloc') return alloc(n.type);
        if (s === 'init') return p;
        if (s === 'release') return '0x0';
        if (s === 'setTag:') { n.tag = a; return '0x0'; }
        if (s === 'viewWithTag:') {
            function find(id) { const x = nodes.get(id); if (x.tag === a) return id; for (const c of x.children) { let y = find(c); if (y) return y; } }
            return find(p) || '0x0';
        }
        if (s === 'addSubview:' || s === 'addArrangedSubview:') { n.children.push(a); nodes.get(a).parent = p; return '0x0'; }
        if (s === 'removeFromSuperview') { let parent = nodes.get(n.parent); if (parent) parent.children = parent.children.filter(x => x !== p); return '0x0'; }
        if (s === 'setOn:') { n.on = !!a; return '0x0'; }
        if (s === 'setHidden:') { n.hidden = !!a; return '0x0'; }
        if (s === 'isOn') return n.on ? '0x1' : '0x0';
        if (s.endsWith('Anchor')) return alloc('anchor');
        if (s === 'constraintEqualToAnchor:') return alloc('constraint');
        if (/Color$/.test(s)) return alloc('color');
        return '0x0';
    }
    let context = {r_class: alloc, r_msg2_main: msg, r_nsstr: () => alloc('string'), r_sel: s => s,
        log: x => logs.push(x), setInterval: fn => { let id = next++; timers.set(id, fn); return id; },
        clearInterval: id => timers.delete(id)};
    if (backend) {
        context.cy_chams_set_enabled = on => { calls.push(['set', on]); return !failSet; };
        context.cy_chams_stop = () => { calls.push(['stop']); return true; };
    }
    vm.runInNewContext(source, context);
    const byTag = t => [...nodes.entries()].find(([p, n]) => n.tag === t);
    return {nodes, win, timers, calls, logs, msg, byTag};
}
const absent = create(false);
assert.equal(absent.timers.size, 0);
assert.equal(absent.nodes.get(absent.win).children.length, 0);

const a = create();
assert.equal(a.timers.size, 1);
let tick = [...a.timers.values()][0];
a.byTag(734933)[1].on = true; tick();
assert.deepEqual(a.calls, [['set', true]]);
a.byTag(734934)[1].on = false; tick();
assert.equal(a.byTag(734932)[1].hidden, true);
a.byTag(734934)[1].on = true; tick();
assert.equal(a.byTag(734932)[1].hidden, false);
a.msg(a.byTag(734931)[0], 'removeFromSuperview'); tick();
assert.deepEqual(a.calls, [['set', true], ['stop']]);
assert.equal(a.timers.size, 0);

const b = create(true, true);
b.byTag(734933)[1].on = true; [...b.timers.values()][0]();
assert.deepEqual(b.calls, [['set', true], ['stop']]);
assert.equal(b.timers.size, 0);
assert.equal(b.nodes.get(b.win).children.length, 0);
console.log('Menu logic passed with a mock UI and mock backend; no device verification.');
