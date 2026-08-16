import{CONFIG}from'./config.js';import{getClient,sendMagicLink,escapeHtml}from'./auth.js';const $=s=>document.querySelector(s);let client,caseRow;
async function showPortal(){client=await getClient();const{data:{user}}=await client.auth.getUser();if(!user)return;const{data:c,error}=await client.from('customer_cases').select('id,lead_id,customer_user_id,status,public_next_step,customer_message').eq('customer_user_id',user.id).maybeSingle();$('#portal-auth').hidden=true;if(error||!c){$('#portal-empty').hidden=false;return}const[{data:req},{data:quote},{data:items},{data:installations},{data:support}]=await Promise.all([client.from('lead_requirements').select('sites_count,current_setup,pain_points,problem_description,customer_summary').eq('lead_id',c.lead_id).maybeSingle(),client.from('quote_workflows').select('status,premitel_quote_reference,official_quote_url').eq('customer_case_id',c.id).maybeSingle(),client.from('onboarding_items').select('id,document_type,label,status,conditional_reason,customer_guidance,official_form_reference').eq('customer_case_id',c.id).order('created_at'),client.from('installations').select('status,scheduled_for,completed_at,porting_status,public_update,safe_setup_summary').eq('customer_case_id',c.id),client.from('support_requests').select('id,subject,status,premitel_reference,created_at').eq('customer_case_id',c.id).order('created_at',{ascending:false})]);caseRow=c;$('#portal-view').hidden=false;render({...c,requirement:req,quote,items:items||[],installations:installations||[],support:support||[]})}
function safeLink(url){try{const u=new URL(url);return u.protocol==='https:'&&CONFIG.allowedQuoteHosts.some(h=>u.hostname===h||u.hostname.endsWith('.'+h))?u.href:null}catch{return null}}
function render(c){$('#case-title').textContent='Phone-system journey';$('#case-stage').textContent=c.status;$('#case-next-step').textContent=c.public_next_step||c.customer_message||'We will update this case when the next step is confirmed.';const url=safeLink(c.quote?.official_quote_url);if(url){$('#quote-link-wrap').hidden=false;$('#quote-link').href=url}else $('#secure-instructions').textContent=c.quote?.premitel_quote_reference?'Official quote reference: '+c.quote.premitel_quote_reference:'Louise will provide the secure submission instructions.';const r=c.requirement;$('#portal-requirements').innerHTML=r?`<p><strong>Locations:</strong> ${r.sites_count}</p><p><strong>Current setup:</strong> ${escapeHtml(r.current_setup||'To be confirmed')}</p><p><strong>Outcomes:</strong> ${escapeHtml((r.pain_points||[]).join(', ')||'To be confirmed')}</p><p>${escapeHtml(r.customer_summary||r.problem_description||'Requirements are being confirmed.')}</p>`:'<p>Requirements are being prepared.</p>';$('#checklist').innerHTML=c.items.map(i=>`<li><span>${escapeHtml(i.status)}</span>${escapeHtml(i.label)}${i.customer_guidance?'<br>'+escapeHtml(i.customer_guidance):''}</li>`).join('')||'<li>Checklist not started.</li>';const ins=c.installations[0];$('#installation').innerHTML=ins?`<p><span class="badge">${escapeHtml(ins.status)}</span></p><p>${escapeHtml(ins.public_update||ins.safe_setup_summary||'Installation details will appear here.')}</p><p>Porting: ${escapeHtml(ins.porting_status||'Not applicable or not started')}</p>`:'<p>Installation begins after quote acceptance and onboarding completion.</p>';renderSupport(c.support)}
function renderSupport(rows){$('#support-list').innerHTML=rows.map(r=>`<li><span>${escapeHtml(r.status)}</span>${escapeHtml(r.subject)}${r.premitel_reference?' · '+escapeHtml(r.premitel_reference):''}</li>`).join('')||'<li>No support requests.</li>'}
$('#show-signup').onclick = (e) => { e.preventDefault(); $('#portal-login-form').hidden = true; $('#portal-signup-form').hidden = false; $('#auth-title').textContent = 'Create Account'; $('#auth-desc').textContent = 'Sign up to view your case.'; };
$('#show-login-from-signup').onclick = (e) => { e.preventDefault(); $('#portal-signup-form').hidden = true; $('#portal-login-form').hidden = false; $('#auth-title').textContent = 'Sign in'; $('#auth-desc').textContent = 'Portal access is invited only after a real formal quote exists.'; };
$('#show-reset').onclick = (e) => { e.preventDefault(); $('#portal-login-form').hidden = true; $('#portal-reset-form').hidden = false; $('#auth-title').textContent = 'Reset Password'; $('#auth-desc').textContent = 'Enter your email to receive a password reset link.'; };
$('#show-login-from-reset').onclick = (e) => { e.preventDefault(); $('#portal-reset-form').hidden = true; $('#portal-login-form').hidden = false; $('#auth-title').textContent = 'Sign in'; $('#auth-desc').textContent = 'Portal access is invited only after a real formal quote exists.'; };

import { signInWithPassword, signUpWithPassword, resetPasswordForEmail } from './auth.js';

$('#portal-login-form').onsubmit = async e => {
  e.preventDefault();
  const status = $('#login-status');
  status.className = 'form-status';
  status.textContent = 'Signing in...';
  const { error } = await signInWithPassword(client, $('#login-email').value, $('#login-password').value);
  if (error) {
    status.className = 'form-status error';
    status.textContent = error.message;
  } else {
    status.textContent = '';
    await showPortal();
  }
};

$('#portal-signup-form').onsubmit = async e => {
  e.preventDefault();
  const status = $('#signup-status');
  status.className = 'form-status';
  status.textContent = 'Creating account...';
  const { error } = await signUpWithPassword(client, $('#signup-email').value, $('#signup-password').value);
  if (error) {
    status.className = 'form-status error';
    status.textContent = error.message;
  } else {
    status.className = 'form-status success';
    status.textContent = 'Account created. Signing you in...';
    setTimeout(showPortal, 1000);
  }
};

$('#portal-reset-form').onsubmit = async e => {
  e.preventDefault();
  const status = $('#reset-status');
  status.className = 'form-status';
  status.textContent = 'Sending...';
  const redirectTo = new URL('portal/reset-password.html', location.origin).href;
  const { error } = await resetPasswordForEmail(client, $('#reset-email').value, redirectTo);
  if (error) {
    status.className = 'form-status error';
    status.textContent = error.message;
  } else {
    status.className = 'form-status success';
    status.textContent = 'Reset link sent! Check your email.';
  }
};

$('#support-form').onsubmit=async e=>{e.preventDefault();const status=$('#support-status'),subject=$('#support-subject').value.trim(),message=$('#support-message').value.trim();const{data:{user}}=await client.auth.getUser();const{error}=await client.from('support_requests').insert({customer_case_id:caseRow.id,requester_user_id:user.id,subject,message,status:'new'});status.className='form-status';status.textContent=error?'Unable to create the request.':'Support request created.';if(error) status.classList.add('error'); else status.classList.add('success'); if(!error){e.currentTarget.reset();await showPortal()}};document.querySelectorAll('.js-signout').forEach(b=>b.onclick=async()=>{await client.auth.signOut();location.reload()});client=await getClient();await showPortal();
