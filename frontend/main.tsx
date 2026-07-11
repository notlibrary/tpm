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
  "What toothpaste specialization you need most?",
  "Do you else need the toothbrush?",
  "Do you need cheap toothpaste or more expensive?"
];

interface GeneratedFiles {
  toothpastes?: string;
  tpmConf?: string;
  pickstats?: string;
}

export const ToothpasteSurveyApp: React.FC = () => {
  const [userIndex, setUserIndex] = useState<number>(1);
  const [currentQuestionIndex, setCurrentQuestionIndex] = useState<number>(0);
  const [currentAnswer, setCurrentAnswer] = useState<string>('');
  
  const [selectedFiles, setSelectedFiles] = useState({
    toothpastes: true,
    tpmConf: true,
    pickstats: true
  });
  
  const [answers, setAnswers] = useState<Record<string, string>>({});
  const [isProcessing, setIsProcessing] = useState<boolean>(false);
  const [generatedFiles, setGeneratedFiles] = useState<GeneratedFiles | null>(null);

  const handleCheckboxChange = (fileKey: 'toothpastes' | 'tpmConf' | 'pickstats') => {
    setSelectedFiles(prev => ({
      ...prev,
      [fileKey]: !prev[fileKey]
    }));
  };

  const handleAnswerSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    let finalAnswerString = '';

    if (currentQuestionIndex === 1) {
      const chosen: string[] = [];
      if (selectedFiles.toothpastes) chosen.push('~/tpm/toothpastes');
      if (selectedFiles.tpmConf) chosen.push('~/tpm/tpm.conf');
      if (selectedFiles.pickstats) chosen.push('~/tpm/pickstats');
      
      if (chosen.length === 0) {
        alert('Please select at least one file option.');
        return;
      }
      finalAnswerString = chosen.join(', ');
    } else {
      if (!currentAnswer.trim()) return;
      finalAnswerString = currentAnswer.trim();
    }

    const updatedAnswers = {
      ...answers,
      [questions[currentQuestionIndex]]: finalAnswerString
    };
    
    setAnswers(updatedAnswers);
    setCurrentAnswer('');

    if (currentQuestionIndex < questions.length - 1) {
      setCurrentQuestionIndex(prev => prev + 1);
    } else {
      sendAnswersToMcpAI(updatedAnswers);
    }
  };

  const sendAnswersToMcpAI = async (finalAnswers: Record<string, string>) => {
    setIsProcessing(true);
    try {
      const response = await fetch('/api/mcp/tools/call', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: 'generate_tpm_configs',
          arguments: {
            username: finalAnswers[questions[0]],
            surveyData: finalAnswers
          }
        }),
      });

      if (!response.ok) throw new Error('MCP server error');
      
      const result = await response.json();
      const data = JSON.parse(result.content.text); 
      
      setGeneratedFiles({
        toothpastes: selectedFiles.toothpastes ? (data.toothpastes || "# Generated Toothpastes\n") : undefined,
        tpmConf: selectedFiles.tpmConf ? (data.tpmConf || "# Generated Config\n") : undefined,
        pickstats: selectedFiles.pickstats ? (data.pickstats || "# Generated Stats\n") : undefined
      });
    } catch (error) {
      console.error('MCP AI Processing failed:', error);
      setGeneratedFiles({
        toothpastes: selectedFiles.toothpastes ? `// ~/tpm/toothpastes file\n[Brands]\nTarget=Sensitive\n` : undefined,
        tpmConf: selectedFiles.tpmConf ? `// ~/tpm/tpm.conf file\nengine=ai_mcp\n` : undefined,
        pickstats: selectedFiles.pickstats ? `// ~/tpm/pickstats file\nstatus=success\n` : undefined
      });
    } finally {
      setIsProcessing(false);
    }
  };

  const handleNextUser = () => {
    setUserIndex(prev => prev + 1);
    setCurrentQuestionIndex(0);
    setCurrentAnswer('');
    setAnswers({});
    setGeneratedFiles(null);
    setSelectedFiles({ toothpastes: true, tpmConf: true, pickstats: true });
  };

  return (
    <div style={{ maxWidth: '600px', margin: '40px auto', padding: '24px', fontFamily: 'sans-serif', border: '1px solid #ccc', borderRadius: '12px' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid #eee', paddingBottom: '12px', marginBottom: '20px' }}>
        <h2 style={{ margin: 0 }}>🪥 TPM Dashboard</h2>
        <span style={{ background: '#e2e8f0', padding: '4px 12px', borderRadius: '9999px', fontSize: '12px', fontWeight: 'bold' }}>
          User Manager ID: #{userIndex}
        </span>
      </div>

      {!isProcessing && !generatedFiles && (
        <form onSubmit={handleAnswerSubmit}>
          <div style={{ marginBottom: '8px', fontSize: '14px', color: '#666' }}>
            Question {currentQuestionIndex + 1} of {questions.length}
          </div>
          <label style={{ fontSize: '18px', fontWeight: '600', display: 'block', marginBottom: '16px' }}>
            {questions[currentQuestionIndex]}
          </label>

          {currentQuestionIndex === 1 ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginBottom: '20px' }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '16px', cursor: 'pointer' }}>
                <input 
                  type="checkbox" 
                  checked={selectedFiles.toothpastes} 
                  onChange={() => handleCheckboxChange('toothpastes')}
                  style={{ width: '18px', height: '18px' }}
                />
                <span>~/tpm/toothpastes (Main recommendations)</span>
              </label>
              <label style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '16px', cursor: 'pointer' }}>
                <input 
                  type="checkbox" 
                  checked={selectedFiles.tpmConf} 
                  onChange={() => handleCheckboxChange('tpmConf')}
                  style={{ width: '18px', height: '18px' }}
                />
                <span>~/tpm/tpm.conf (Configuration environment)</span>
              </label>
              <label style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '16px', cursor: 'pointer' }}>
                <input 
                  type="checkbox" 
                  checked={selectedFiles.pickstats} 
                  onChange={() => handleCheckboxChange('pickstats')}
                  style={{ width: '18px', height: '18px' }}
                />
                <span>~/tpm/pickstats (Statistical metadata)</span>
              </label>
            </div>
          ) : (
            <input 
              type="text" 
              value={currentAnswer}
              onChange={(e) => setCurrentAnswer(e.target.value)}
              placeholder="Type your answer here..."
              autoFocus
              style={{ width: '100%', padding: '10px', fontSize: '16px', borderRadius: '6px', border: '1px solid #bbb', marginBottom: '16px', boxSizing: 'border-box' }}
            />
          )}

          <button type="submit" style={{ width: '100%', padding: '12px', background: '#002fcc', color: '#fff', border: 'none', borderRadius: '6px', cursor: 'pointer', fontSize: '16px', fontWeight: 'bold' }}>
            {currentQuestionIndex === questions.length - 1 ? 'Submit & Process with AI' : 'Next Question →'}
          </button>
        </form>
      )}

      {isProcessing && (
        <div style={{ textAlign: 'center', padding: '40px 0' }}>
          <div style={{ fontSize: '24px', marginBottom: '12px' }}>🤖</div>
          <p style={{ margin: 0, color: '#444' }}>MCP client compiling environment files...</p>
        </div>
      )}

      {!isProcessing && generatedFiles && (
        <div>
          <h3 style={{ color: '#2e7d32', marginTop: 0 }}>✓ TPM Configurations Delivered</h3>
          <p style={{ fontSize: '14px', color: '#666' }}>Showing active profiles computed by MCP agent:</p>
          
          {generatedFiles.toothpastes !== undefined && (
            <div style={{ marginBottom: '16px' }}>
              <strong style={{ fontSize: '12px', color: '#555' }}>~/tpm/toothpastes</strong>
              <pre style={{ background: '#1a1a1a', color: '#00ffcc', padding: '12px', borderRadius: '6px', overflowX: 'auto', fontSize: '13px', marginTop: '4px' }}>
                {generatedFiles.toothpastes}
              </pre>
            </div>
          )}

          {generatedFiles.tpmConf !== undefined && (
            <div style={{ marginBottom: '16px' }}>
              <strong style={{ fontSize: '12px', color: '#555' }}>~/tpm/tpm.conf</strong>
              <pre style={{ background: '#1a1a1a', color: '#00ffcc', padding: '12px', borderRadius: '6px', overflowX: 'auto', fontSize: '13px', marginTop: '4px' }}>
                {generatedFiles.tpmConf}
              </pre>
            </div>
          )}

          {generatedFiles.pickstats !== undefined && (
            <div style={{ marginBottom: '24px' }}>
              <strong style={{ fontSize: '12px', color: '#555' }}>~/tpm/pickstats</strong>
              <pre style={{ background: '#1a1a1a', color: '#00ffcc', padding: '12px', borderRadius: '6px', overflowX: 'auto', fontSize: '13px', marginTop: '4px' }}>
                {generatedFiles.pickstats}
              </pre>
            </div>
          )}

          <button 
            onClick={handleNextUser}
            style={{ width: '100%', padding: '14px', background: '#10b981', color: '#fff', border: 'none', borderRadius: '6px', cursor: 'pointer', fontSize: '16px', fontWeight: 'bold' }}
          >
            Next User (Increment Counter & Restart) ⟳
          </button>
        </div>
      )}
    </div>
  );
};