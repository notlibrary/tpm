/* 
	Toothpaste picking manager frontend survey source code 0BSD license
*/

/* 
Algorithm as follows
1. Ask user questions
2. Pass the answers to AI with MCP
3. Get AI recommendation in Toothpaste picking manager format 
   generated `~/tpm/toothpastes` `~/tpm/tpm.conf` `~/tpm/pickstats` files 
 Next user increment counter go to 1
*/
/* 
	Toothpaste picking manager frontend survey source code 0BSD license
*/

/* 
Algorithm as follows
1. Ask user questions
2. Pass the answers to AI with MCP
3. Get AI recommendation in Toothpaste picking manager format 
   generated `~/tpm/toothpastes` `~/tpm/tpm.conf` `~/tpm/pickstats` files 
 Next user increment counter go to 1
*/
import React, { useState } from 'react';

const questions: string[] = [
  "What is your username?", 
  "What TPM files do you need?", 
  "How old are you?",
  "How many toothpaste brands you need?",
  "Where are you from?",
  "What toothpaste components required?",
  "What toothpaste components to skip?",
  "Are you smoking?",
  "Are you drinking red whine?",
  "Do you like chocolate?",
  "What toothpaste specialization you need most?",
  "Your dental formula?(ie. 2-2-2-2)",
  "Do you else need the toothbrush?",
  "Do you need cheap toothpaste or more expensive?",
  "What is your favorite meme?"
];

const default_answers: string[] = [
  "Anonymous", 
  "all", 
  "25",
  "3",
  "US",
  "abrasive, fluoride, foam, odor",
  "none",
  "no",
  "no",
  "no",
  "complex protection",
  "2-2-2-2",
  "no",
  "cheap",
  "sup /b/"
];

//export const ToothpasteSurveyApp = () => {
export default function App() {
  const [userIndex, setUserIndex] = useState(1);
  const [currentIdx, setCurrentIdx] = useState(0);
  const [answer, setAnswer] = useState(default_answers[0]);
  const [files, setFiles] = useState({ toothpastes: true, tpmConf: true, pickstats: true });
  const [answers, setAnswers] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<any>(null);

  const handleCheckboxChange = (fileKey: 'toothpastes' | 'tpmConf' | 'pickstats') => {
    setFiles(prev => ({
      ...prev,
      [fileKey]: !prev[fileKey]
    }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    let val = currentIdx === 1 
      ? Object.keys(files).filter(k => files[k as keyof typeof files]).map(k => `~/tpm/${k}`).join(', ') 
      : answer.trim();

    if (currentIdx === 1 && !val) return alert('Select a file');
    if (currentIdx !== 1 && !val) return;

    const nextAnswers = { ...answers, [questions[currentIdx]]: val };
    setAnswers(nextAnswers);

    const nextIdx = currentIdx + 1;
    if (nextIdx < questions.length) {
      setCurrentIdx(nextIdx);
      setAnswer(default_answers[nextIdx] || '');
      return;
    }

    setLoading(true);
    try {
      const res = await fetch('/api/mcp/tools/call', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: 'generate_tpm_configs', arguments: { username: nextAnswers[questions[0]], surveyData: nextAnswers } })
      });
      const data = JSON.parse((await res.json()).content.text);
      setResult({
        toothpastes: files.toothpastes ? data.toothpastes || "# Toothpastes\n" : null,
        tpmConf: files.tpmConf ? data.tpmConf || "# Config\n" : null,
        pickstats: files.pickstats ? data.pickstats || "# Stats\n" : null
      });
    } catch {
      setResult({
        toothpastes: files.toothpastes ? `[Brands]\nTarget=Sensitive\n` : null,
        tpmConf: files.tpmConf ? `engine=ai_mcp\n` : null,
        pickstats: files.pickstats ? `status=success\n` : null
      });
    }
    setLoading(false);
  };

  const reset = () => {
    setUserIndex(u => u + 1);
    setCurrentIdx(0);
    setAnswer(default_answers[0]);
    setAnswers({});
    setResult(null);
  };

  return (
    <div style={{ maxWidth: '650px', width: '100%', margin: '40px auto', padding: '24px', fontFamily: 'sans-serif', border: '1px solid #ccc', borderRadius: '12px', boxSizing: 'border-box' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid #eee', paddingBottom: '12px', marginBottom: '20px' }}>
        <div>
          <h3 style={{ margin: 0 }}>🪥 TPM Dashboard</h3>
          <a href="https://github.com" target="_blank" rel="noreferrer" style={{ fontSize: '11px', color: '#002fcc', textDecoration: 'none' }}>Releases ↗</a>
        </div>
        <span style={{ fontSize: '12px', fontWeight: 'bold', background: '#e2e8f0', padding: '4px 10px', borderRadius: '12px' }}>ID: #{userIndex}</span>
      </div>

      {!loading && !result && (
        <form onSubmit={handleSubmit} style={{ width: '100%' }}>
          <div style={{ fontSize: '12px', color: '#666', marginBottom: '8px' }}>Q: {currentIdx + 1}/{questions.length}</div>
          <label style={{ fontWeight: '600', display: 'block', marginBottom: '16px', fontSize: '16px', lineHeight: '1.4' }}>{questions[currentIdx]}</label>
          
          {currentIdx === 1 ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', marginBottom: '20px' }}>
              <label style={{ display: 'flex', gap: '8px', cursor: 'pointer', alignItems: 'center' }}>
                <input type="checkbox" checked={files.toothpastes} onChange={() => handleCheckboxChange('toothpastes')} />
                <span style={{ fontFamily: 'monospace' }}>~/tpm/toothpastes</span>
              </label>
              <label style={{ display: 'flex', gap: '8px', cursor: 'pointer', alignItems: 'center' }}>
                <input type="checkbox" checked={files.tpmConf} onChange={() => handleCheckboxChange('tpmConf')} />
                <span style={{ fontFamily: 'monospace' }}>~/tpm/tpm.conf</span>
              </label>
              <label style={{ display: 'flex', gap: '8px', cursor: 'pointer', alignItems: 'center' }}>
                <input type="checkbox" checked={files.pickstats} onChange={() => handleCheckboxChange('pickstats')} />
                <span style={{ fontFamily: 'monospace' }}>~/tpm/pickstats</span>
              </label>
            </div>
          ) : (
            <input type="text" value={answer} onChange={e => setAnswer(e.target.value)} autoFocus style={{ width: '100%', padding: '10px', marginBottom: '20px', boxSizing: 'border-box', border: '1px solid #ccc', borderRadius: '6px', fontSize: '15px' }} />
          )}
          <button type="submit" style={{ width: '100%', padding: '12px', background: '#002fcc', color: '#fff', border: 'none', borderRadius: '6px', cursor: 'pointer', fontSize: '15px', fontWeight: 'bold' }}>
            {currentIdx === questions.length - 1 ? 'Process with AI' : 'Next →'}
          </button>
        </form>
      )}

      {loading && <p style={{ textAlign: 'center', margin: '40px 0' }}>🤖 Compiling with MCP...</p>}

      {result && (
        <div style={{ width: '100%' }}>
          <h4 style={{ color: '#2e7d32', margin: '0 0 16px 0', fontSize: '18px' }}>✓ Configs Delivered</h4>
          {Object.entries(result).map(([k, v]) => v && (
            <div key={k} style={{ marginTop: '16px', width: '100%' }}>
              <span style={{ fontSize: '12px', color: '#555', display: 'block', marginBottom: '4px', fontFamily: 'monospace' }}>~/tpm/{k}</span>
              <pre style={{ background: '#1a1a1a', color: '#00ffcc', padding: '14px', borderRadius: '6px', overflowX: 'auto', margin: 0, fontSize: '13px', width: '100%', boxSizing: 'border-box', whiteSpace: 'pre-wrap' }}>{v as string}</pre>
            </div>
          ))}
          <button onClick={reset} style={{ width: '100%', padding: '12px', background: '#10b981', color: '#fff', border: 'none', borderRadius: '6px', cursor: 'pointer', marginTop: '24px', fontSize: '15px', fontWeight: 'bold' }}>Next User ⟳</button>
        </div>
      )}
    </div>
  );
};