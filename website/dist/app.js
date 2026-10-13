const slider = document.querySelector('#time-slider');
const buttons = [...document.querySelectorAll('[data-hour]')];
const blend = (a, b, fraction) => 1e6 / ((1e6 / a) * (1 - fraction) + (1e6 / b) * fraction);
function schedule(hour) {
  if (hour < 6) return [2300, 'Bedtime'];
  if (hour < 7) {
    const t = hour - 6;
    return [blend(blend(3400, 6500, t), 2300, 1 - t), 'Morning transition'];
  }
  if (hour < 18.5) return [6500, 'Daytime'];
  if (hour < 19.5) return [blend(6500, 3400, hour - 18.5), 'Sunset transition'];
  if (hour < 21.5) return [3400, 'Sunset'];
  if (hour < 22.5) return [blend(3400, 2300, hour - 21.5), 'Bedtime transition'];
  return [2300, 'Bedtime'];
}
function showTime(hour) {
  const [kelvin, phase] = schedule(hour);
  const minutes = Math.round(hour * 60) % 1440;
  const clockHour = Math.floor(minutes / 60);
  const time = `${clockHour % 12 || 12}:${String(minutes % 60).padStart(2, '0')} ${clockHour < 12 ? 'AM' : 'PM'}`;
  const formatted = `${Math.round(kelvin).toLocaleString('en-US')} K`;
  document.querySelector('#demo-time').textContent = time;
  document.querySelector('#demo-phase').textContent = phase;
  document.querySelector('#demo-kelvin').textContent = formatted;
  slider.value = hour;
  slider.setAttribute('aria-valuetext', `${time}, ${phase}, ${Math.round(kelvin)} kelvin`);
  buttons.forEach(button => button.setAttribute('aria-pressed', String(Number(button.dataset.hour) === hour)));
  const x = 30 + hour * 35;
  const y = 30 + (6500 - kelvin) / 4200 * 124;
  const marker = document.querySelector('#demo-marker');
  marker.setAttribute('x1', x); marker.setAttribute('x2', x);
  document.querySelector('#demo-point').setAttribute('cx', x);
  document.querySelector('#demo-point').setAttribute('cy', y);
}
// Plot the same schedule used by the marker rather than a separately approximated curve.
const samples = Array.from({ length: 241 }, (_, i) => {
  const hour = i / 10;
  return `${30 + hour * 35},${30 + (6500 - schedule(hour)[0]) / 4200 * 124}`;
});
const line = 'M' + samples.join(' L');
document.querySelector('.curve-line').setAttribute('d', line);
document.querySelector('.curve-area').setAttribute('d', line + ' L870,175 L30,175 Z');
slider.addEventListener('input', () => showTime(Number(slider.value)));
buttons.forEach(button => button.addEventListener('click', () => showTime(Number(button.dataset.hour))));
showTime(Number(slider.value));
