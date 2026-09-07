// ClipForge 前端逻辑 - 原生 JS,无框架
// 调后端 /api/* 端点,UI 状态管理

const $ = (s) => document.querySelector(s);
const $$ = (s) => document.querySelectorAll(s);

// ==================== 标签页切换 ====================
$$('.tab').forEach(btn => {
  btn.addEventListener('click', () => {
    $$('.tab').forEach(b => b.classList.remove('active'));
    $$('.panel').forEach(p => p.classList.remove('active'));
    btn.classList.add('active');
    const target = btn.dataset.tab;
    document.getElementById(target).classList.add('active');
  });
});

// ==================== 工具函数 ====================
function setStatus(el, text, kind) {
  el.textContent = text || '';
  el.className = 'status' + (kind ? ' ' + kind : '');
}

async function api(method, path, body, isForm) {
  const opts = { method, headers: {} };
  if (body && !isForm) {
    opts.headers['Content-Type'] = 'application/json';
    opts.body = JSON.stringify(body);
  } else if (body && isForm) {
    opts.body = body;  // FormData,浏览器自动设 Content-Type
  }
  const r = await fetch(path, opts);
  if (!r.ok) {
    let msg = 'HTTP ' + r.status;
    try { const j = await r.json(); if (j.error) msg = j.error; } catch {}
    throw new Error(msg);
  }
  const ct = r.headers.get('content-type') || '';
  if (ct.includes('application/json')) return await r.json();
  return await r.text();
}

async function uploadFile(file) {
  const fd = new FormData();
  fd.append('file', file);
  return await api('POST', '/api/upload', fd, true);
}

// ==================== 设置页 ====================
async function loadSettings() {
  try {
    const c = await api('GET', '/api/config');
    const el = $('#settings-status');
    if (c.configured) {
      el.textContent = '✓ 已配置 API Key(明文存储在本地)';
      el.className = 'hint';
    }
  } catch (e) { console.warn(e); }
}

$('#settings-save').addEventListener('click', async () => {
  const key = $('#settings-key').value.trim();
  if (!key) { setStatus($('#settings-status'), '请先输入 API Key', 'warn'); return; }
  try {
    await api('POST', '/api/config', { apiKey: key });
    setStatus($('#settings-status'), '✓ 已保存到本地', 'ok');
    $('#settings-key').value = '';
  } catch (e) {
    setStatus($('#settings-status'), '保存失败: ' + e.message, 'err');
  }
});

$('#settings-clear').addEventListener('click', async () => {
  try {
    await api('POST', '/api/config', { apiKey: '' });
    setStatus($('#settings-status'), '已清除', 'ok');
  } catch (e) {
    setStatus($('#settings-status'), '清除失败: ' + e.message, 'err');
  }
});

// ==================== 声音工坊 ====================
let _cloneFile = null;

$('#voice-pick').addEventListener('click', () => $('#voice-file').click());
$('#voice-file').addEventListener('change', (e) => {
  _cloneFile = e.target.files[0];
  $('#voice-filename').textContent = _cloneFile ? _cloneFile.name : '未选择';
});

$('#voice-clone').addEventListener('click', async () => {
  if (!_cloneFile) { setStatus($('#voice-status'), '请先选择参考音频', 'warn'); return; }
  const prefix = $('#voice-prefix').value.trim() || 'myvoice';
  setStatus($('#voice-status'), '正在上传音频到 OSS…', 'warn');
  try {
    const up = await uploadFile(_cloneFile);
    setStatus($('#voice-status'), '已上传,提交克隆任务…', 'warn');
    const create = await api('POST', '/api/voice/create', {
      model: 'cosyvoice-v3.5-plus',
      input: { action: 'create_voice', target_model: 'cosyvoice-v3.5-plus', prefix, url: up.resource }
    });
    const voiceId = create.output.voice_id;
    setStatus($('#voice-status'), `已提交,voice_id = ${voiceId},开始轮询…`, 'warn');

    // 轮询 30 次,每 10 秒
    for (let i = 0; i < 30; i++) {
      await new Promise(r => setTimeout(r, 10000));
      const q = await api('GET', `/api/voice/list?voice_id=${encodeURIComponent(voiceId)}`);
      const status = q.output?.status;
      setStatus($('#voice-status'), `轮询 #${i+1}: status = ${status}`, 'warn');
      if (status === 'OK') { setStatus($('#voice-status'), `✅ 克隆成功:${voiceId}`, 'ok'); break; }
      if (status === 'UNDEPLOYED') { setStatus($('#voice-status'), '❌ 克隆失败(音频质量不达标)', 'err'); break; }
    }
    loadVoices();
  } catch (e) {
    setStatus($('#voice-status'), '❌ ' + e.message, 'err');
  }
});

async function loadVoices() {
  const sel = $('#voice-list');
  sel.innerHTML = '<option>— 加载中 —</option>';
  try {
    const prefix = $('#voice-prefix').value.trim() || 'myvoice';
    const r = await api('GET', `/api/voice/list?prefix=${encodeURIComponent(prefix)}`);
    const voices = r.output?.voices || [];
    if (!voices.length) { sel.innerHTML = '<option>— 暂无 —</option>'; return; }
    sel.innerHTML = voices.map(v => `<option value="${v.voice_id}">${v.voice_id}</option>`).join('');
  } catch (e) {
    sel.innerHTML = '<option>— 加载失败 —</option>';
    setStatus($('#voice-status'), '加载音色失败: ' + e.message, 'err');
  }
}
$('#voice-refresh').addEventListener('click', loadVoices);

// ==================== 视频工坊 ====================
let _videoImage = null, _videoAudio = null;

$('#video-pick-image').addEventListener('click', () => $('#video-image').click());
$('#video-image').addEventListener('change', (e) => {
  _videoImage = e.target.files[0];
  $('#video-image-name').textContent = _videoImage ? _videoImage.name : '未选择';
});
$('#video-pick-audio').addEventListener('click', () => $('#video-audio').click());
$('#video-audio').addEventListener('change', (e) => {
  _videoAudio = e.target.files[0];
  $('#video-audio-name').textContent = _videoAudio ? _videoAudio.name : '未选择';
});

$('#video-submit').addEventListener('click', async () => {
  const prompt = $('#video-prompt').value.trim();
  if (!prompt) { setStatus($('#video-status'), '请输入提示词', 'warn'); return; }

  setStatus($('#video-status'), '正在上传参考资源(如有)…', 'warn');
  try {
    let imgUrl = '', audioUrl = '';
    if (_videoImage) {
      const up = await uploadFile(_videoImage);
      imgUrl = up.resource;
      setStatus($('#video-status'), '参考图已上传,上传参考音频…', 'warn');
    }
    if (_videoAudio) {
      const up = await uploadFile(_videoAudio);
      audioUrl = up.resource;
    }

    const req = {
      model: 'wan2.6-i2v',
      input: {
        prompt,
        ...(imgUrl && { img_url: imgUrl }),
        ...(audioUrl && { audio_url: audioUrl })
      },
      parameters: {
        resolution: $('#video-resolution').value,
        prompt_extend: $('#video-extend').checked,
        duration: parseInt($('#video-duration').value, 10),
        shot_type: $('#video-shottype').value
      }
    };
    setStatus($('#video-status'), '提交任务…', 'warn');
    const submit = await api('POST', '/api/video/submit', req);
    const taskId = submit.output.task_id;
    setStatus($('#video-status'), `任务 ${taskId.slice(0, 8)}… 提交成功,开始轮询`, 'warn');

    // 轮询 30 分钟,每 8 秒
    const deadline = Date.now() + 30 * 60 * 1000;
    while (Date.now() < deadline) {
      await new Promise(r => setTimeout(r, 8000));
      const t = await api('GET', `/api/video/task?taskId=${encodeURIComponent(taskId)}`);
      const status = t.output?.task_status || 'RUNNING';
      setStatus($('#video-status'), `任务 ${taskId.slice(0, 8)}… 状态:${status}`, 'warn');
      if (status === 'SUCCEEDED') {
        const url = t.output.video_url;
        setStatus($('#video-status'), '✅ 生成完成,正在显示…', 'ok');
        $('#video-result').innerHTML = `
          <video controls src="${url}"></video>
          <a href="${url}" target="_blank" download>在新标签页打开</a>
        `;
        return;
      }
      if (status === 'FAILED' || status === 'CANCELED') {
        const msg = t.output?.message || '未知失败原因';
        setStatus($('#video-status'), '❌ ' + msg, 'err');
        return;
      }
    }
    setStatus($('#video-status'), '⏱️ 轮询超时(30 分钟)', 'err');
  } catch (e) {
    setStatus($('#video-status'), '❌ ' + e.message, 'err');
  }
});

// ==================== 启动 ====================
loadSettings();
loadVoices();
