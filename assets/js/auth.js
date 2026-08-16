import { CONFIG } from './config.js';
export async function getClient(){if(!window.supabase)await new Promise((ok,no)=>{const s=document.createElement('script');s.src='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2';s.onload=ok;s.onerror=no;document.head.append(s)});return window.supabase.createClient(CONFIG.supabaseUrl,CONFIG.supabaseAnonKey)}
export async function sendMagicLink(client,email,redirectTo,shouldCreateUser=false){return client.auth.signInWithOtp({email,options:{emailRedirectTo:redirectTo,shouldCreateUser}})}
export async function currentProfile(client){const{data:{user}}=await client.auth.getUser();if(!user)return{user:null,profile:null};const{data,error}=await client.from('profiles').select('user_id,full_name,role,active').eq('user_id',user.id).maybeSingle();if(error)throw error;const profile=data?{id:data.user_id,display_name:data.full_name,role:data.active?data.role:'inactive'}:null;return{user,profile}}
export const escapeHtml=value=>String(value??'').replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));
export async function signInWithPassword(client,email,password){return client.auth.signInWithPassword({email,password})}
export async function signUpWithPassword(client,email,password){return client.auth.signUp({email,password})}
export async function resetPasswordForEmail(client,email,redirectTo){return client.auth.resetPasswordForEmail(email,{redirectTo})}
export async function updateUserPassword(client,password){return client.auth.updateUser({password})}
