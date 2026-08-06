import { CONFIG } from './config.js';
export async function getClient(){if(!window.supabase)await new Promise((ok,no)=>{const s=document.createElement('script');s.src='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2';s.onload=ok;s.onerror=no;document.head.append(s)});return window.supabase.createClient(CONFIG.supabaseUrl,CONFIG.supabaseAnonKey)}
export async function sendMagicLink(client,email,redirectTo){return client.auth.signInWithOtp({email,options:{emailRedirectTo:redirectTo,shouldCreateUser:false}})}
export async function currentProfile(client){const{data:{user}}=await client.auth.getUser();if(!user)return{user:null,profile:null};const{data:profile,error}=await client.from('profiles').select('id,display_name,role').eq('id',user.id).maybeSingle();if(error)throw error;return{user,profile}}
export const escapeHtml=value=>String(value??'').replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));
