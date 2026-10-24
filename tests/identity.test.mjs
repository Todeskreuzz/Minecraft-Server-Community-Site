import test from 'node:test';
import assert from 'node:assert/strict';
import {selectLanguage,authorName,mayPost} from '../assets/js/forum-identity.mjs';
test('automatic language respects first supported browser preference',()=>{
 assert.equal(selectLanguage(['de-AT','en-US']),'de');
 assert.equal(selectLanguage(['en-GB','de-DE']),'en');
 assert.equal(selectLanguage(['fr-FR','de-DE']),'de');
 assert.equal(selectLanguage(['fr-FR']),'en');
 assert.equal(selectLanguage([]),'en');
 assert.equal(selectLanguage(['de-DE'],'en'),'en');
});
test('owner label is localized without leaking a hidden name',()=>{
 assert.equal(authorName({is_owner:true,display_name:null},'de'),'Inhaber');
 assert.equal(authorName({is_owner:true,display_name:null},'en'),'Owner');
 assert.equal(authorName({is_owner:true,display_name:'Tim'},'de'),'Tim');
 assert.equal(authorName({is_owner:false,display_name:'Alex'},'de'),'Alex');
 assert.equal(authorName(undefined,'en'),'Member');
});
test('read-only visitors and anonymous auth users cannot post',()=>{
 assert.equal(mayPost(null),false);
 assert.equal(mayPost({user:{is_anonymous:true}}),false);
 assert.equal(mayPost({user:{id:'member',is_anonymous:false}}),true);
});
