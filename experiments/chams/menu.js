// EXPERIMENTAL SOURCE. Requires native cy_chams_set_enabled / cy_chams_stop.
// Neither function is currently exposed; this file is not a working tweak.
(function () {
    'use strict';
    if (typeof cy_chams_set_enabled !== 'function' || typeof cy_chams_stop !== 'function') {
        log('Chams backend unavailable; menu not started.');
        return;
    }
    var ROOT_TAG = 734931, MENU_TAG = 734932, ENABLE_TAG = 734933, TRIGGER_TAG = 734934;
    var timer = 0, root = '0x0', window = '0x0', owned = false, stopped = false;
    var lastTrigger = true, lastEnabled = false;
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
    }
    try {
        window = msg(msg(r_class('UIApplication'), 'sharedApplication'), 'keyWindow');
        if (!valid(window)) throw new Error('SpringBoard window unavailable');
        var old = msg(window, 'viewWithTag:', ROOT_TAG);
        if (valid(old)) throw new Error('Existing menu: exit it before starting another');
        root = object('UIStackView'); owned = true;
        msg(root, 'setTag:', ROOT_TAG);
        msg(root, 'setAxis:', 1);
        msg(root, 'setAlignment:', 1);
        msg(root, 'setTranslatesAutoresizingMaskIntoConstraints:', 0);

        var trigger = object('UISwitch');
        msg(trigger, 'setTag:', TRIGGER_TAG); msg(trigger, 'setOn:', 1);
        add(root, trigger);
        var menu = object('UIStackView');
        msg(menu, 'setTag:', MENU_TAG); msg(menu, 'setAxis:', 1); msg(menu, 'setAlignment:', 1);
        msg(menu, 'setLayoutMarginsRelativeArrangement:', 1);
        msg(menu, 'setBackgroundColor:', msg(r_class('UIColor'), 'secondarySystemBackgroundColor'));

        var row = object('UIStackView');
        msg(row, 'setAxis:', 0); msg(row, 'setAlignment:', 3);
        var label = object('UILabel'); text(label, 'setText:', ' Chams ');
        msg(label, 'setTextColor:', msg(r_class('UIColor'), 'labelColor')); add(row, label);
        var enabled = object('UISwitch'); msg(enabled, 'setTag:', ENABLE_TAG); msg(enabled, 'setOn:', 0);
        add(row, enabled); add(menu, row);

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
                var check = msg(current, 'viewWithTag:', ENABLE_TAG);
                if (!valid(toggle) || !valid(menuNow) || !valid(check)) throw new Error('Menu removed');
                var show = valid(msg(toggle, 'isOn'));
                if (show !== lastTrigger) { msg(menuNow, 'setHidden:', show ? 0 : 1); lastTrigger = show; }
                var on = valid(msg(check, 'isOn'));
                if (on !== lastEnabled) {
                    if (cy_chams_set_enabled(on) !== true) {
                        log('Chams change failed; restoration not confirmed.');
                        stop(true); return;
                    }
                    lastEnabled = on;
                }
            } catch (e) { log('Menu error: ' + String(e)); stop(true); }
        }, 250);
    } catch (e) { log('Menu setup failed: ' + String(e)); stop(true); }
}());
