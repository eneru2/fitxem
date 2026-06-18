const API_BASE = window.JUST_CLOCK_API || 'http://localhost:8080';

document.getElementById('register-form')?.addEventListener('submit', async (e) => {
  e.preventDefault();
  const form = e.target;
  const msg = document.getElementById('form-msg');
  msg.textContent = 'Registrando...';

  const data = Object.fromEntries(new FormData(form));
  try {
    const res = await fetch(`${API_BASE}/auth/register-org`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    const body = await res.json();
    if (!res.ok) throw new Error(body.error || 'Error al registrar');
    msg.textContent = '¡Cuenta creada! Descarga la app o inicia sesión.';
    msg.style.color = '#16a34a';
  } catch (err) {
    msg.textContent = err.message;
    msg.style.color = '#dc2626';
  }
});
