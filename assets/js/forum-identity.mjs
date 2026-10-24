export function selectLanguage(languages=[],choice='auto'){
 if(choice==='de'||choice==='en')return choice;
 for(const language of languages){const base=String(language).toLowerCase().split('-')[0];if(base==='de'||base==='en')return base}
 return 'en';
}
export function authorName(profile,language){
 if(profile?.is_owner)return profile.display_name||(language==='de'?'Inhaber':'Owner');
 return profile?.display_name||(language==='de'?'Mitglied':'Member');
}
export function mayPost(session){return Boolean(session?.user?.id&&!session.user.is_anonymous)}
