import { getClient, updateUserPassword } from './auth.js';

const $ = s => document.querySelector(s);
let client;

async function init() {
  client = await getClient();
  
  // Verify that we are on a recovery hash or a signed-in session
  const { data: { session } } = await client.auth.getSession();
  
  $('#reset-password-form').onsubmit = async e => {
    e.preventDefault();
    const status = $('#reset-status');
    status.className = 'form-status';
    status.textContent = 'Updating...';
    
    const newPassword = $('#new-password').value;
    const { error } = await updateUserPassword(client, newPassword);
    
    if (error) {
      status.className = 'form-status error';
      status.textContent = error.message;
    } else {
      status.className = 'form-status success';
      status.textContent = 'Password updated successfully. Redirecting...';
      setTimeout(() => {
        window.location.href = './index.html';
      }, 1500);
    }
  };
}

init();
