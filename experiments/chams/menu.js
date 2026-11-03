// EXPERIMENTAL: requires the matching Cyanide WIP branch and device testing.
(function () {
    'use strict';
    if (typeof cy_chams_set_mode !== 'function' || typeof cy_chams_stop !== 'function' ||
        typeof cy_chams_refresh !== 'function' || typeof cy_chams_window_open !== 'function' ||
        typeof cy_chams_window_close !== 'function') {
        log('Chams backend unavailable; menu not started.');
        return;
    }
    var ROOT_TAG = 734931, MENU_TAG = 734932, TRIGGER_TAG = 734934, MODE_BASE = 734940;
    var timer = 0, root = '0x0', window = '0x0', owned = false, stopped = false;
    var lastTrigger = false, ticks = 0, lastModes = [false, false, false, false, false, false, false];
    var modeNames = ['Chams', 'Chams 1', 'Blacked', 'Test 221', 'Chams 2', 'Wireframe', 'Flat Chams'];
    function valid(p) { return p != null && !/^(?:0x)?0+$/i.test(String(p)); }
    function msg(o, s, a, b, c, d) { return r_msg2_main(o, s, a || 0, b || 0, c || 0, d || 0); }
    function object(name) {
        var c = r_class(name), o = valid(c) ? msg(msg(c, 'alloc'), 'init') : 0;
        if (!valid(o)) throw new Error('Cannot create ' + name);
        return o;
    }
    function text(o, selector, value, state) {
        var str = r_nsstr(value);
        try { msg(o, selector, str, state || 0); } finally { msg(str, 'release'); }
    }
    function add(parent, child) { msg(parent, 'addArrangedSubview:', child); msg(child, 'release'); }
    function stop(remove) {
        if (stopped) return;
        stopped = true;
        if (timer) { clearInterval(timer); timer = 0; }
        var ok = false;
        try { ok = cy_chams_stop() === true; } catch (e) { log('Chams stop failed: ' + String(e)); }
        if (!ok) log('Chams restoration was not confirmed.');
        if (remove && valid(window)) {
            var current = msg(window, 'viewWithTag:', ROOT_TAG);
            if (valid(current) && String(current) === String(root)) msg(current, 'removeFromSuperview');
        }
        if (owned) { msg(root, 'release'); owned = false; }
        if (valid(window) && cy_chams_window_close() !== true) log('Menu window cleanup was not confirmed.');
        window = '0x0';
    }
    try {
        window = cy_chams_window_open();
        if (!valid(window)) throw new Error('SpringBoard window unavailable');
        var old = msg(window, 'viewWithTag:', ROOT_TAG);
        if (valid(old)) throw new Error('Existing menu: exit it before starting another');
        root = object('UIStackView'); owned = true;
        msg(root, 'setTag:', ROOT_TAG);
        msg(root, 'setAxis:', 1);
        msg(root, 'setAlignment:', 1);
        msg(root, 'setTranslatesAutoresizingMaskIntoConstraints:', 0);

        var trigger = object('UIButton');
        msg(trigger, 'setTag:', TRIGGER_TAG);
        text(trigger, 'setTitle:forState:', '≡', 0);
        add(root, trigger);
        var menu = object('UIStackView');
        msg(menu, 'setTag:', MENU_TAG); msg(menu, 'setAxis:', 1); msg(menu, 'setAlignment:', 1);
        msg(menu, 'setLayoutMarginsRelativeArrangement:', 1);
        msg(menu, 'setBackgroundColor:', msg(r_class('UIColor'), 'secondarySystemBackgroundColor'));

        var row = object('UIStackView');
        msg(row, 'setAxis:', 0); msg(row, 'setAlignment:', 3);
        var label = object('UILabel'); text(label, 'setText:', ' Chams ');
        msg(label, 'setTextColor:', msg(r_class('UIColor'), 'labelColor')); add(row, label);
        add(menu, row);
        for (var i = 0; i < modeNames.length; i++) {
            var modeRow = object('UIStackView'); msg(modeRow, 'setAxis:', 0); msg(modeRow, 'setAlignment:', 3);
            var modeLabel = object('UILabel'); text(modeLabel, 'setText:', modeNames[i]);
            msg(modeLabel, 'setTextColor:', msg(r_class('UIColor'), 'labelColor')); add(modeRow, modeLabel);
            var modeSwitch = object('UISwitch'); msg(modeSwitch, 'setTag:', MODE_BASE + i); msg(modeSwitch, 'setOn:', 0);
            add(modeRow, modeSwitch); add(menu, modeRow);
        }

        var exitButton = object('UIButton'); text(exitButton, 'setTitle:forState:', 'Exit', 0);
        msg(exitButton, 'setTitleColor:forState:', msg(r_class('UIColor'), 'labelColor'), 0);
        msg(exitButton, 'addTarget:action:forControlEvents:', root, r_sel('removeFromSuperview'), 64);
        add(menu, exitButton); add(root, menu);
        msg(window, 'addSubview:', root);
        var cx = msg(msg(root, 'centerXAnchor'), 'constraintEqualToAnchor:', msg(window, 'centerXAnchor'));
        var cy = msg(msg(trigger, 'centerYAnchor'), 'constraintEqualToAnchor:', msg(window, 'centerYAnchor'));
        if (!valid(cx) || !valid(cy)) throw new Error('Cannot position menu');
        msg(cx, 'setActive:', 1); msg(cy, 'setActive:', 1);
        msg(root, 'release'); owned = false;

        timer = setInterval(function () {
            try {
                var current = msg(window, 'viewWithTag:', ROOT_TAG);
                if (!valid(current) || String(current) !== String(root)) { stop(false); return; }
                var toggle = msg(current, 'viewWithTag:', TRIGGER_TAG);
                var menuNow = msg(current, 'viewWithTag:', MENU_TAG);
                if (!valid(toggle) || !valid(menuNow)) throw new Error('Menu removed');
                var pressed = valid(msg(toggle, 'isHighlighted'));
                if (pressed && !lastTrigger) {
                    var hidden = valid(msg(menuNow, 'isHidden'));
                    msg(menuNow, 'setHidden:', hidden ? 0 : 1);
                }
                lastTrigger = pressed;
                var anyOn = false;
                for (var mode = 0; mode < modeNames.length; mode++) {
                    var check = msg(current, 'viewWithTag:', MODE_BASE + mode);
                    if (!valid(check)) throw new Error('Mode checkbox missing');
                    var on = valid(msg(check, 'isOn'));
                    anyOn = anyOn || on;
                    if (on !== lastModes[mode]) {
                        if (cy_chams_set_mode(mode, on) !== true) {
                            log(modeNames[mode] + ' failed; material restore was not confirmed.');
                            stop(true); return;
                        }
                        lastModes[mode] = on;
                    }
                }
                if (++ticks >= 10) {
                    ticks = 0;
                    if (cy_chams_window_refresh() !== true) { log('Window refresh failed.'); stop(true); return; }
                    if (anyOn && cy_chams_refresh() !== true) { log('Chams refresh failed.'); stop(true); return; }
                }
            } catch (e) { log('Menu error: ' + String(e)); stop(true); }
        }, 50);
    } catch (e) { log('Menu setup failed: ' + String(e)); stop(true); }
}());
