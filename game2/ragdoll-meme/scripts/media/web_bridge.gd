extends RefCounted
class_name WebBridge

## Browser-side helpers the Web export leans on, installed into the page
## once. The browser is better at four things this demo needs than Godot's
## Web build is:
##
##   RagdollEmoji      renders an emoji with the device's own emoji font
##                     (Godot's default font has no emoji glyphs at all)
##   RagdollText       meme captions (Impact + black outline, wrapped),
##                     emoji included
##   RagdollLoadImage  fetches a photo from any URL -- directly when the
##                     host allows CORS, else through the wsrv.nl image
##                     proxy -- decodes any format the browser can (gif,
##                     avif, heic on Safari...), downsizes, returns PNG
##   RagdollPickImage  the device photo picker / camera roll
##   RagdollSfx        plays the sound effects (Sfx) through the page's own
##                     Web Audio graph, which the recorder can tap -- Godot's
##                     Web audio can't be reached from the page
##   RagdollRec        records the stage part of the canvas to a video
##                     (MediaRecorder, mp4 where supported, else webm), with
##                     RagdollSfx's sound mixed in, and shows a preview with
##                     Share / Download
##
## The recorder can read the WebGL canvas at any time because the export's
## head_include forces preserveDrawingBuffer on (export_presets.cfg).

static var _installed := false

static func available() -> bool:
	return OS.has_feature("web")

static func ensure() -> bool:
	if not available():
		return false
	if not _installed:
		JavaScriptBridge.eval(JS, true)
		_installed = true
	return true

## Decode a base64 PNG (no data: prefix) into a texture.
static func png_texture(b64: String) -> ImageTexture:
	if b64 == "":
		return null
	var img := Image.new()
	if img.load_png_from_buffer(Marshalls.base64_to_raw(b64)) != OK:
		return null
	return ImageTexture.create_from_image(img)

const JS := """
(function () {
if (window.RagdollBridge) return;
window.RagdollBridge = true;
var EMOJI_FONT = '"Apple Color Emoji","Segoe UI Emoji","Noto Color Emoji","Twemoji Mozilla","EmojiOne Color",sans-serif';

function isBlank(ctx, w, h) {
	var d = ctx.getImageData(0, 0, w, h).data;
	for (var i = 3; i < d.length; i += 4) { if (d[i] > 0) return false; }
	return true;
}

window.RagdollEmoji = function (s, size) {
	var c = document.createElement('canvas');
	c.width = size; c.height = size;
	var x = c.getContext('2d');
	x.textAlign = 'center'; x.textBaseline = 'middle';
	x.font = Math.floor(size * 0.8) + 'px ' + EMOJI_FONT;
	x.fillText(s, size / 2, size * 0.54);
	if (isBlank(x, size, size)) return '';
	return c.toDataURL('image/png').split(',')[1];
};

window.RagdollText = function (text, px, maxW, meme) {
	var font = meme
		? ('900 ' + px + 'px Impact, Anton, "Arial Black", "Helvetica Neue", sans-serif, ' + EMOJI_FONT)
		: ('600 ' + px + 'px system-ui, -apple-system, "Segoe UI", Roboto, sans-serif, ' + EMOJI_FONT);
	var c = document.createElement('canvas');
	var x = c.getContext('2d');
	x.font = font;
	var lines = [];
	String(text).split('\\n').forEach(function (para) {
		if (!(maxW > 0)) { lines.push(para); return; }
		var words = para.split(/\\s+/), line = '';
		for (var i = 0; i < words.length; i++) {
			var t = line ? line + ' ' + words[i] : words[i];
			if (x.measureText(t).width > maxW && line) { lines.push(line); line = words[i]; }
			else line = t;
		}
		lines.push(line);
	});
	var stroke = meme ? Math.max(2, Math.round(px / 7)) : 0;
	var pad = stroke + 6;
	var w = 1;
	for (var j = 0; j < lines.length; j++) w = Math.max(w, x.measureText(lines[j]).width);
	var lh = Math.round(px * 1.12);
	c.width = Math.ceil(w + pad * 2);
	c.height = Math.ceil(lh * lines.length + pad * 2);
	x = c.getContext('2d');
	x.font = font; x.textAlign = 'center'; x.textBaseline = 'top'; x.lineJoin = 'round';
	for (var k = 0; k < lines.length; k++) {
		var y = pad + k * lh;
		if (meme) {
			x.lineWidth = stroke * 2; x.strokeStyle = '#000';
			x.strokeText(lines[k], c.width / 2, y);
		} else {
			x.shadowColor = 'rgba(0,0,0,0.55)'; x.shadowBlur = 5; x.shadowOffsetY = 1;
		}
		x.fillStyle = '#fff';
		x.fillText(lines[k], c.width / 2, y);
	}
	return c.toDataURL('image/png').split(',')[1];
};

window.RagdollLoadImage = function (url, maxSide, cb) {
	var tries = [url];
	if (!/^(data|blob):/.test(url)) {
		tries.push('https://wsrv.nl/?url=' + encodeURIComponent(url) + '&w=' + maxSide + '&h=' + maxSide + '&fit=inside&output=png');
	}
	var k = 0;
	function next() {
		if (k >= tries.length) { cb(''); return; }
		var img = new Image();
		img.crossOrigin = 'anonymous';
		img.onload = function () {
			try {
				var s = Math.min(1, maxSide / Math.max(img.naturalWidth, img.naturalHeight));
				var c = document.createElement('canvas');
				c.width = Math.max(1, Math.round(img.naturalWidth * s));
				c.height = Math.max(1, Math.round(img.naturalHeight * s));
				c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
				cb(c.toDataURL('image/png'));
			} catch (e) { next(); }
		};
		img.onerror = function () { next(); };
		img.src = tries[k++];
	}
	next();
};

window.RagdollPickImage = function (maxSide, cb) {
	var input = document.createElement('input');
	input.type = 'file'; input.accept = 'image/*'; input.style.display = 'none';
	document.body.appendChild(input);
	input.onchange = function () {
		var f = input.files && input.files[0];
		document.body.removeChild(input);
		if (!f) { cb(''); return; }
		var u = URL.createObjectURL(f);
		window.RagdollLoadImage(u, maxSide, function (d) { URL.revokeObjectURL(u); cb(d); });
	};
	input.click();
};

window.RagdollSfx = (function () {
	var ctx = null, master = null, dest = null, buffers = {}, volume = 1;
	function context() {
		if (ctx) return ctx;
		var AC = window.AudioContext || window.webkitAudioContext;
		if (!AC) return null;
		ctx = new AC();
		master = ctx.createGain();
		master.gain.value = volume;
		master.connect(ctx.destination);
		return ctx;
	}
	// Browsers only let audio start from inside a real user gesture, and
	// Godot handles input later, in its own frame -- so unlock on the raw
	// DOM events instead.
	function unlock() {
		var c = context();
		if (c && c.state !== 'running') c.resume().catch(function () {});
	}
	['pointerdown', 'touchend', 'keydown', 'mousedown'].forEach(function (t) {
		window.addEventListener(t, unlock, true);
	});
	return {
		load: function (name, b64) {
			var c = context();
			if (!c) return;
			var bin = atob(b64), bytes = new Uint8Array(bin.length);
			for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
			c.decodeAudioData(bytes.buffer, function (b) { buffers[name] = b; }, function () {});
		},
		play: function (name, gain, rate, pan) {
			var c = context(), b = buffers[name];
			if (!c || !b || c.state !== 'running') return;
			var src = c.createBufferSource();
			src.buffer = b;
			src.playbackRate.value = rate;
			var g = c.createGain();
			g.gain.value = gain;
			src.connect(g);
			var out = g;
			if (c.createStereoPanner) {
				var p = c.createStereoPanner();
				p.pan.value = pan;
				g.connect(p);
				out = p;
			}
			out.connect(master);
			src.start();
		},
		setVolume: function (v) { volume = v; if (master) master.gain.value = v; },
		loaded: function () { return Object.keys(buffers).length; },
		state: function () { return ctx ? ctx.state : 'none'; },
		// A MediaStream carrying everything the effects play, for the recorder.
		stream: function () {
			var c = context();
			if (!c || !c.createMediaStreamDestination) return null;
			if (!dest) { dest = c.createMediaStreamDestination(); master.connect(dest); }
			return dest.stream;
		}
	};
})();

window.RagdollRec = (function () {
	var rec = null, out = null, ctx = null, src = null, raf = 0, crop = [0, 0, 1, 1], chunks = [], mime = '';
	var TYPES = ['video/mp4;codecs=avc1.42E01E', 'video/mp4;codecs=avc1', 'video/mp4',
		'video/webm;codecs=vp9', 'video/webm;codecs=vp8', 'video/webm'];
	// With a sound track the codec list has to name an audio codec too, or
	// Chrome refuses the stream. Bare containers ('video/mp4') let the
	// browser choose both.
	var AV_TYPES = ['video/mp4;codecs=avc1.42E01E,mp4a.40.2', 'video/mp4;codecs=avc1,mp4a.40.2',
		'video/mp4;codecs=avc1,opus', 'video/mp4', 'video/webm;codecs=vp9,opus',
		'video/webm;codecs=vp8,opus', 'video/webm'];
	function pick(withAudio) {
		var list = withAudio ? AV_TYPES : TYPES;
		for (var i = 0; i < list.length; i++) {
			if (MediaRecorder.isTypeSupported && MediaRecorder.isTypeSupported(list[i])) return list[i];
		}
		return '';
	}
	function draw() {
		if (!rec) return;
		ctx.fillStyle = '#000';
		ctx.fillRect(0, 0, out.width, out.height);
		try { ctx.drawImage(src, crop[0], crop[1], crop[2], crop[3], 0, 0, out.width, out.height); } catch (e) {}
		raf = requestAnimationFrame(draw);
	}
	function button(label, bg) {
		var b = document.createElement('button');
		b.textContent = label;
		b.style.cssText = 'font:600 17px system-ui,sans-serif;padding:12px 18px;border:0;border-radius:12px;color:#fff;background:' + bg + ';cursor:pointer;';
		return b;
	}
	function show(blob) {
		var ext = /mp4/.test(blob.type) ? 'mp4' : 'webm';
		var stamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
		var name = 'ragdoll-meme-' + stamp + '.' + ext;
		var url = URL.createObjectURL(blob);
		var file = null;
		try { file = new File([blob], name, { type: blob.type }); } catch (e) {}
		var o = document.createElement('div');
		o.id = 'ragdoll-rec-overlay';
		o.style.cssText = 'position:fixed;inset:0;z-index:1000;background:rgba(8,8,14,0.92);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:14px;padding:16px;box-sizing:border-box;';
		var v = document.createElement('video');
		v.src = url; v.autoplay = true; v.loop = true; v.muted = true; v.playsInline = true; v.controls = false;
		// Try with sound; if the browser won't autoplay audio here, stay
		// muted and let a tap on the video turn it on.
		v.muted = false;
		v.play().catch(function () { v.muted = true; v.play().catch(function () {}); });
		v.onclick = function () { v.muted = !v.muted; };
		v.style.cssText = 'max-width:100%;max-height:calc(100% - 130px);border-radius:14px;box-shadow:0 8px 40px rgba(0,0,0,0.6);background:#000;';
		var row = document.createElement('div');
		row.style.cssText = 'display:flex;gap:10px;flex-wrap:wrap;justify-content:center;';
		var tip = document.createElement('div');
		tip.style.cssText = 'color:#aab;font:14px system-ui,sans-serif;text-align:center;max-width:420px;';
		tip.textContent = window.RagdollRec.lastAudio
			? 'The sound effects are in the clip (tap it to mute). Tip: add a trending sound on top when you post it.'
			: 'Tip: add a trending sound when you post it.';
		if (file && navigator.canShare && navigator.canShare({ files: [file] })) {
			var share = button('Share', '#ff2d6f');
			share.onclick = function () {
				navigator.share({ files: [file], title: 'My ragdoll meme' }).catch(function () {});
			};
			row.appendChild(share);
		}
		var dl = button('Download', '#3b82f6');
		dl.onclick = function () {
			var a = document.createElement('a');
			a.href = url; a.download = name;
			document.body.appendChild(a); a.click(); document.body.removeChild(a);
		};
		row.appendChild(dl);
		var close = button('Back to editing', '#44475a');
		close.onclick = function () { v.pause(); URL.revokeObjectURL(url); o.remove(); };
		row.appendChild(close);
		o.appendChild(v); o.appendChild(row); o.appendChild(tip);
		document.body.appendChild(o);
		window.RagdollRec.lastFile = name;
		window.RagdollRec.lastSize = blob.size;
	}
	return {
		lastFile: '', lastSize: 0, lastError: '', lastAudio: false,
		supported: function () {
			return !!(window.MediaRecorder && HTMLCanvasElement.prototype.captureStream);
		},
		setCrop: function (x, y, w, h) { crop = [x, y, Math.max(1, w), Math.max(1, h)]; },
		start: function (x, y, w, h, ow, oh, fps) {
			if (rec) return mime;
			try {
				src = document.getElementById('canvas');
				out = document.createElement('canvas');
				out.width = ow; out.height = oh;
				ctx = out.getContext('2d');
				crop = [x, y, Math.max(1, w), Math.max(1, h)];
				var stream = out.captureStream(fps);
				var sfx = window.RagdollSfx && window.RagdollSfx.stream();
				var audio = sfx ? sfx.getAudioTracks()[0] : null;
				if (audio) stream.addTrack(audio);
				mime = pick(!!audio);
				window.RagdollRec.lastAudio = !!audio;
				chunks = [];
				var opts = { videoBitsPerSecond: 8000000 };
				if (mime) opts.mimeType = mime;
				rec = new MediaRecorder(stream, opts);
				rec.ondataavailable = function (e) { if (e.data && e.data.size) chunks.push(e.data); };
				rec.onstop = function () {
					var type = (rec && rec.mimeType) || mime || 'video/webm';
					rec = null;
					cancelAnimationFrame(raf);
					// The sound track is shared with RagdollSfx -- only stop the video.
					stream.getVideoTracks().forEach(function (t) { t.stop(); });
					show(new Blob(chunks, { type: type.split(';')[0] }));
				};
				rec.start(250);
				draw();
				window.RagdollRec.lastError = '';
				return mime || 'default';
			} catch (e) {
				rec = null;
				window.RagdollRec.lastError = String(e);
				return '';
			}
		},
		stop: function () { if (rec && rec.state !== 'inactive') rec.stop(); },
		recording: function () { return !!rec; },
		overlayOpen: function () { return !!document.getElementById('ragdoll-rec-overlay'); }
	};
})();
})();
"""
