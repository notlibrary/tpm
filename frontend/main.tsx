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

// Type definitions
interface TPMConfig {
  CONSTANTS: {
    LOAD_CONFIG: string;
    DEFAULT: number;
    TRUE: number;
    FALSE: number;
  };
  GENERAL: {
    USERNAME: string;
    PICK_TYPE: string;
    DENTAL_FORMULA: string;
    VERBOSE: boolean;
    TOOTHPASTES: string;
    LAST_PICK: string;
    PICK_STATS: string;
    LIST_TOOTHPASTES: boolean;
    OUTPUT_JSON: boolean;
    OUTPUT_CSV: boolean;
    FAKE_STATS: boolean;
    OUTPUT_FILE: boolean;
    PICK_INDEX: number;
    RESET_COUNTER: boolean;
    SET_COUNTER: number;
    BRAND: string;
    UPPER_BRANDS: boolean;
    TIMEZONE: number;
    DELTA_DAYS: number;
    MEME: string;
    TEMPLATE: string;
    LOCALE: string;
  };
}

// Binary pickstats struct (C representation)
interface ToothpastePickStats {
  last_pick_time: number;  // time_t
  total_picks: number;     // unsigned int
}

interface ResultType {
  toothpastes: string | null;
  tpmConf: string | null;
  pickstats: string | null;
}

interface Toothbrush {
  color: string;
  brand: string;
  length_cm: number;
  hardness: number;
}

const welcome_msg: string = `Welcome to the Toothpaste picking manager frontend survey
Everything is completely anonymous 
We do not save your personal data and using it only to produce high quality AI recommendation
Then clean and remove everything`;

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
  "Do you experience pain from cold or acidic food?",
  "Do you have braces, implants, or crowns?",
  "Are you looking for an organic/fluoride-free configuration?",
  "What is your favorite meme?",
  "What is your pick type style?",
  "Enable verbose logging mode?",
  "List toothpastes on startup?",
  "Output results in JSON format?",
  "Output results in CSV format?",
  "Generate fake statistical logs?",
  "Write outputs directly to a file?",
  "What initial pick index to use?",
  "Reset internal pick counter?",
  "Set explicit counter starting point?",
  "What bathroom brand do you prefer?",
  "Force brand names to UPPERCASE?",
  "What is your current timezone offset?(hours)",
  "Delta days parameter adjustment?",
  "What config layout template code?",
  "What interface localization language?",
  "Add this answer to AI system prompt?"
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
  "no",
  "no",
  "no",
  "no",
  "sup/b/",
  "DEFAULT",
  "TRUE",
  "FALSE",
  "FALSE",
  "FALSE",
  "FALSE",
  "FALSE",
  "0",
  "FALSE",
  "0",
  "SENSODYNE",
  "FALSE",
  "0",
  "0",
  "guwntdapobiTfWPlUsmI",
  "en_US",
  "Thanks you"
];

// Generate binary pickstats file
function generateBinaryPickStats(stats: ToothpastePickStats): Uint8Array {
  const buffer = new ArrayBuffer(12);
  const view = new DataView(buffer);
  
  view.setBigUint64(0, BigInt(stats.last_pick_time), true);
  view.setUint32(8, stats.total_picks, true);
  
  return new Uint8Array(buffer);
}

// Generate enhanced toothpaste file with toothbrush info
function generateToothpastesEnhanced(answers: Record<string, string>): string {
  const brands = parseInt(answers[questions[3]]) || 3;
  const specialization = answers[questions[10]] || "complex protection";
  const smoking = answers[questions[7]]?.toLowerCase() === "yes";
  const whine = answers[questions[8]]?.toLowerCase() === "yes";
  const chocolate = answers[questions[9]]?.toLowerCase() === "yes";
  const pain = answers[questions[14]]?.toLowerCase() === "yes";
  const braces = answers[questions[15]]?.toLowerCase() === "yes";
  const organic = answers[questions[16]]?.toLowerCase() === "yes";
  const cheap = answers[questions[13]]?.toLowerCase() === "cheap";
  const needsBrush = answers[questions[12]]?.toLowerCase() === "yes";

  // Brand database with realistic values
  const brandDatabase = [
    { name: 'LACALUT', price: 100, rating: 90, color: 'White', brand: 'Lacalut', fluoride: 19, abrasiveness: 50 },
    { name: 'CREST', price: 161, rating: 90, color: 'Black', brand: 'Lacalut', fluoride: 19, abrasiveness: 50 },
    { name: 'SENSODYNE', price: 150, rating: 100, color: 'White', brand: 'Lacalut', fluoride: 19, abrasiveness: 50 },
    { name: 'COLGATE', price: 120, rating: 85, color: 'White', brand: 'Colgate', fluoride: 15, abrasiveness: 45 },
    { name: 'AQUAFRESH', price: 110, rating: 88, color: 'Blue', brand: 'Aquafresh', fluoride: 14, abrasiveness: 40 },
    { name: 'ARM & HAMMER', price: 95, rating: 82, color: 'Orange', brand: 'Arm&Hammer', fluoride: 12, abrasiveness: 35 },
    { name: 'TOMS', price: 130, rating: 78, color: 'Green', brand: 'Toms', fluoride: 0, abrasiveness: 30 },
    { name: 'HELLO', price: 125, rating: 80, color: 'Pink', brand: 'Hello', fluoride: 10, abrasiveness: 38 },
    { name: 'BURT\'S BEES', price: 140, rating: 76, color: 'Yellow', brand: 'BurtsBees', fluoride: 0, abrasiveness: 28 },
    { name: 'CLOSYS', price: 145, rating: 84, color: 'Red', brand: 'CloSYS', fluoride: 11, abrasiveness: 42 },
  ];

  // Toothbrush database
  const toothbrushDatabase: Toothbrush[] = [
    { color: 'Black', brand: 'Random toothbrush', length_cm: 20, hardness: 50 },
    { color: 'White', brand: 'Random toothbrush', length_cm: 25, hardness: 25 },
    { color: 'Pink', brand: 'Random toothbrush', length_cm: 20, hardness: 50 },
    { color: 'Green', brand: 'Random toothbrush', length_cm: 20, hardness: 50 },
    { color: 'Blue', brand: 'Random toothbrush', length_cm: 22, hardness: 40 },
    { color: 'Red', brand: 'Random toothbrush', length_cm: 18, hardness: 60 },
    { color: 'Purple', brand: 'Random toothbrush', length_cm: 21, hardness: 35 },
    { color: 'Orange', brand: 'Random toothbrush', length_cm: 19, hardness: 45 },
  ];

  // Filter brands based on preferences
  let selectedBrands = brandDatabase;
  
  if (organic) {
    selectedBrands = selectedBrands.filter(b => b.fluoride === 0);
  }
  
  if (pain) {
    selectedBrands = selectedBrands.sort((a, b) => {
      if (a.name === 'SENSODYNE') return -1;
      if (b.name === 'SENSODYNE') return 1;
      return 0;
    });
  }
  
  if (cheap) {
    selectedBrands = selectedBrands.sort((a, b) => a.price - b.price);
  }
  
  if (smoking || whine || chocolate) {
    selectedBrands = selectedBrands.sort((a, b) => b.rating - a.rating);
  }

  // Take only the requested number of brands
  const finalBrands = selectedBrands.slice(0, brands);
  
  // Add "Nothing" placeholder if needed
  while (finalBrands.length < brands) {
    finalBrands.push({ 
      name: 'Nothing', 
      price: 0, 
      rating: 0, 
      color: 'Nothing', 
      brand: 'Nothing', 
      fluoride: 0, 
      abrasiveness: 0 
    });
  }

  // Generate enhanced CSV content with toothbrush info
  let content = "#TPM Toothpaste Picking Manager ~/tpm/toothpastes enhanced file\n";
  content += "#Index,Brand string,Tube mass grams,Rating,Toothbrush Color,Toothbrush Brand,Toothbrush Length_cm,Toothbrush Hardness\n";
  content += `# Specialization: ${specialization}\n`;
  
  if (smoking) content += "# Note: Smoker - extra whitening recommended\n";
  if (whine) content += "# Note: Red wine drinker - stain protection recommended\n";
  if (chocolate) content += "# Note: Chocolate lover - cavity protection recommended\n";
  if (pain) content += "# Note: Sensitive teeth - desensitizing recommended\n";
  if (braces) content += "# Note: Braces/implants - gentle formula recommended\n";
  if (organic) content += "# Note: Organic/fluoride-free preference\n";
  if (cheap) content += "# Note: Budget-friendly options\n";
  if (needsBrush) content += "# Note: Toothbrush included with recommendation\n";
  
  finalBrands.forEach((brand, index) => {
    const brush = needsBrush ? toothbrushDatabase[index % toothbrushDatabase.length] : 
      { color: 'Nothing', brand: 'Nothing', length_cm: 0, hardness: 0 };
    content += `${index},${brand.name},${brand.price},${brand.rating},${brush.color},${brush.brand},${brush.length_cm},${brush.hardness}\n`;
  });
  
  return content;
}

// Generate normal toothpaste file (without toothbrush info)
function generateToothpastesNormal(answers: Record<string, string>): string {
  const brands = parseInt(answers[questions[3]]) || 3;
  const specialization = answers[questions[10]] || "complex protection";
  const smoking = answers[questions[7]]?.toLowerCase() === "yes";
  const whine = answers[questions[8]]?.toLowerCase() === "yes";
  const chocolate = answers[questions[9]]?.toLowerCase() === "yes";
  const pain = answers[questions[14]]?.toLowerCase() === "yes";
  const braces = answers[questions[15]]?.toLowerCase() === "yes";
  const organic = answers[questions[16]]?.toLowerCase() === "yes";
  const cheap = answers[questions[13]]?.toLowerCase() === "cheap";

  // Brand database with realistic values
  const brandDatabase = [
    { name: 'LACALUT', price: 100, rating: 90 },
    { name: 'CREST', price: 161, rating: 90 },
    { name: 'SENSODYNE', price: 150, rating: 100 },
    { name: 'COLGATE', price: 120, rating: 85 },
    { name: 'AQUAFRESH', price: 110, rating: 88 },
    { name: 'ARM & HAMMER', price: 95, rating: 82 },
    { name: 'TOMS', price: 130, rating: 78 },
    { name: 'HELLO', price: 125, rating: 80 },
    { name: 'BURT\'S BEES', price: 140, rating: 76 },
    { name: 'CLOSYS', price: 145, rating: 84 },
  ];

  // Filter brands based on preferences
  let selectedBrands = brandDatabase;
  
  if (organic) {
    // Organic brands are those with lower price (simplified)
    selectedBrands = selectedBrands.filter(b => b.price < 120);
  }
  
  if (pain) {
    selectedBrands = selectedBrands.sort((a, b) => {
      if (a.name === 'SENSODYNE') return -1;
      if (b.name === 'SENSODYNE') return 1;
      return 0;
    });
  }
  
  if (cheap) {
    selectedBrands = selectedBrands.sort((a, b) => a.price - b.price);
  }
  
  if (smoking || whine || chocolate) {
    selectedBrands = selectedBrands.sort((a, b) => b.rating - a.rating);
  }

  // Take only the requested number of brands
  const finalBrands = selectedBrands.slice(0, brands);
  
  // Add "Nothing" placeholder if needed
  while (finalBrands.length < brands) {
    finalBrands.push({ name: 'Nothing', price: 0, rating: 0 });
  }

  // Generate normal CSV content
  let content = "#TPM Toothpaste Picking Manager ~/tpm/toothpastes file\n";
  content += "#id,brand string,tube mass g,rating\n";
  content += `# Specialization: ${specialization}\n`;
  
  if (smoking) content += "# Note: Smoker - extra whitening recommended\n";
  if (whine) content += "# Note: Red wine drinker - stain protection recommended\n";
  if (chocolate) content += "# Note: Chocolate lover - cavity protection recommended\n";
  if (pain) content += "# Note: Sensitive teeth - desensitizing recommended\n";
  if (braces) content += "# Note: Braces/implants - gentle formula recommended\n";
  if (organic) content += "# Note: Organic/fluoride-free preference\n";
  if (cheap) content += "# Note: Budget-friendly options\n";
  
  finalBrands.forEach((brand, index) => {
    content += `${index},${brand.name},${brand.price},${brand.rating}\n`;
  });
  
  return content;
}

// Generate TPM config
function generateTPMConfig(answers: Record<string, string>, username: string): TPMConfig {
  const dentalFormula = answers[questions[11]] || "2-2-2-2";
  const pickType = answers[questions[18]] || "DEFAULT";
  const verbose = answers[questions[19]]?.toUpperCase() === "TRUE";
  const listToothpastes = answers[questions[20]]?.toUpperCase() === "TRUE";
  const outputJson = answers[questions[21]]?.toUpperCase() === "TRUE";
  const outputCsv = answers[questions[22]]?.toUpperCase() === "TRUE";
  const fakeStats = answers[questions[23]]?.toUpperCase() === "TRUE";
  const outputFile = answers[questions[24]]?.toUpperCase() === "TRUE";
  const pickIndex = parseInt(answers[questions[25]]) || 0;
  const resetCounter = answers[questions[26]]?.toUpperCase() === "TRUE";
  const setCounter = parseInt(answers[questions[27]]) || 0;
  const brand = answers[questions[28]] || "Unknown";
  const upperBrands = answers[questions[29]]?.toUpperCase() === "TRUE";
  const timezone = parseInt(answers[questions[30]]) || 0;
  const deltaDays = parseInt(answers[questions[31]]) || 0;
  const meme = answers[questions[17]] || "MOAR";
  const template = answers[questions[32]] || "guwntdapobiTfWPlUsmI";
  const locale = answers[questions[33]] || "en_US.UTF-8";

  return {
    CONSTANTS: {
      LOAD_CONFIG: `C:\\Users\\${username}\\tpm\\tpm.conf`,
      DEFAULT: 0,
      TRUE: 1,
      FALSE: 0
    },
    GENERAL: {
      USERNAME: username,
      PICK_TYPE: pickType,
      DENTAL_FORMULA: dentalFormula,
      VERBOSE: verbose,
      TOOTHPASTES: `C:\\Users\\${username}\\tpm\\toothpastes`,
      LAST_PICK: `C:\\Users\\${username}\\tpm\\last_pick`,
      PICK_STATS: `C:\\Users\\${username}\\tpm\\pickstats`,
      LIST_TOOTHPASTES: listToothpastes,
      OUTPUT_JSON: outputJson,
      OUTPUT_CSV: outputCsv,
      FAKE_STATS: fakeStats,
      OUTPUT_FILE: outputFile,
      PICK_INDEX: pickIndex,
      RESET_COUNTER: resetCounter,
      SET_COUNTER: setCounter,
      BRAND: brand,
      UPPER_BRANDS: upperBrands,
      TIMEZONE: timezone,
      DELTA_DAYS: deltaDays,
      MEME: meme,
      TEMPLATE: template,
      LOCALE: locale
    }
  };
}

// Format config as INI string
function formatConfig(config: TPMConfig): string {
  let str = "[CONSTANTS]\n";
  str += `LOAD_CONFIG="${config.CONSTANTS.LOAD_CONFIG}"\n`;
  str += `DEFAULT=${config.CONSTANTS.DEFAULT}\n`;
  str += `TRUE=${config.CONSTANTS.TRUE}\n`;
  str += `FALSE=${config.CONSTANTS.FALSE}\n`;
  str += "[GENERAL]\n";
  str += `USERNAME="${config.GENERAL.USERNAME}"\n`;
  str += `PICK_TYPE=${config.GENERAL.PICK_TYPE}\n`;
  str += `DENTAL_FORMULA="${config.GENERAL.DENTAL_FORMULA}"\n`;
  str += `VERBOSE=${config.GENERAL.VERBOSE ? "TRUE" : "FALSE"}\n`;
  str += `TOOTHPASTES="${config.GENERAL.TOOTHPASTES}"\n`;
  str += `LAST_PICK="${config.GENERAL.LAST_PICK}"\n`;
  str += `PICK_STATS="${config.GENERAL.PICK_STATS}"\n`;
  str += `LIST_TOOTHPASTES=${config.GENERAL.LIST_TOOTHPASTES ? "TRUE" : "FALSE"}\n`;
  str += `OUTPUT_JSON=${config.GENERAL.OUTPUT_JSON ? "TRUE" : "FALSE"}\n`;
  str += `OUTPUT_CSV=${config.GENERAL.OUTPUT_CSV ? "TRUE" : "FALSE"}\n`;
  str += `FAKE_STATS=${config.GENERAL.FAKE_STATS ? "TRUE" : "FALSE"}\n`;
  str += `OUTPUT_FILE=${config.GENERAL.OUTPUT_FILE ? "TRUE" : "FALSE"}\n`;
  str += `PICK_INDEX=${config.GENERAL.PICK_INDEX}\n`;
  str += `RESET_COUNTER=${config.GENERAL.RESET_COUNTER ? "TRUE" : "FALSE"}\n`;
  str += `SET_COUNTER=${config.GENERAL.SET_COUNTER}\n`;
  str += `BRAND="${config.GENERAL.BRAND}"\n`;
  str += `UPPER_BRANDS=${config.GENERAL.UPPER_BRANDS ? "TRUE" : "FALSE"}\n`;
  str += `TIMEZONE=${config.GENERAL.TIMEZONE}\n`;
  str += `DELTA_DAYS=${config.GENERAL.DELTA_DAYS}\n`;
  str += `MEME=${config.GENERAL.MEME}\n`;
  str += `TEMPLATE="${config.GENERAL.TEMPLATE}"\n`;
  str += `LOCALE="${config.GENERAL.LOCALE}"\n`;
  return str;
}

// Helper function to download a file
function downloadFile(content: string | Uint8Array, filename: string, mimeType: string = 'text/plain') {
  let blobContent: BlobPart;
  if (content instanceof Uint8Array) {
    const buffer = new ArrayBuffer(content.length);
    const view = new Uint8Array(buffer);
    view.set(content);
    blobContent = buffer;
  } else {
    blobContent = content;
  }
  
  const blob = new Blob([blobContent], { type: mimeType });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

export default function App() {
  const [userIndex, setUserIndex] = useState(1);
  const [currentIdx, setCurrentIdx] = useState(0);
  const [answer, setAnswer] = useState<string>(default_answers[0]); 
  const [files, setFiles] = useState({ toothpastes: true, tpmConf: true, pickstats: true });
  const [answers, setAnswers] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<ResultType | null>(null);
  const [copied, setCopied] = useState(false);
  const [showRawJson, setShowRawJson] = useState(false);

  const handleCheckboxChange = (fileKey: 'toothpastes' | 'tpmConf' | 'pickstats') => {
    setFiles(prev => ({ ...prev, [fileKey]: !prev[fileKey] }));
  };

  const handleCopyToClipboard = async () => {
    try {
      await navigator.clipboard.writeText(JSON.stringify(answers, null, 2));
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (err) {
      console.error('Failed to copy text: ', err);
    }
  };

  const downloadAll = () => {
    if (!result) return;
    
    if (result.tpmConf) {
      downloadFile(result.tpmConf, 'tpm.conf');
    }
    
    if (result.toothpastes) {
      downloadFile(result.toothpastes, 'toothpastes');
    }
    
    if (result.pickstats) {
      const hexStr = result.pickstats.replace(/\s/g, '');
      const matches = hexStr.match(/.{1,2}/g);
      const bytes = new Uint8Array(matches?.map((byte: string) => parseInt(byte, 16)) || []);
      downloadFile(bytes, 'pickstats', 'application/octet-stream');
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    let val = currentIdx === 1 
      ? Object.keys(files).filter(k => files[k as keyof typeof files]).map(k => `~/tpm/${k}`).join(', ') 
      : answer.trim();

    if (currentIdx === 1 && !val) return alert('Select at least one file');
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
    setTimeout(() => {
      try {
        const username = nextAnswers[questions[0]] || "Anonymous";
        
        const tpmConfig = generateTPMConfig(nextAnswers, username);
        const configStr = formatConfig(tpmConfig);
        
        // Check if user needs a toothbrush (question 12)
        const needsBrush = nextAnswers[questions[12]]?.toLowerCase() === "yes";
        
        // Generate toothpastes based on toothbrush need
        const toothpastesStr = needsBrush 
          ? generateToothpastesEnhanced(nextAnswers)
          : generateToothpastesNormal(nextAnswers);
        
        const pickStats: ToothpastePickStats = {
          last_pick_time: Math.floor(Date.now() / 1000),
          total_picks: 0
        };
        const binaryData = generateBinaryPickStats(pickStats);
        const hexString = Array.from(binaryData)
          .map(b => b.toString(16).padStart(2, '0'))
          .join(' ');

        setResult({
          toothpastes: files.toothpastes ? toothpastesStr : null,
          tpmConf: files.tpmConf ? configStr : null,
          pickstats: files.pickstats ? hexString : null
        });
      } catch (error) {
        setResult({
          toothpastes: files.toothpastes ? "# Error generating toothpastes\n" : null,
          tpmConf: files.tpmConf ? "# Error generating config\n" : null,
          pickstats: files.pickstats ? "Error" : null
        });
      }
      setLoading(false);
    }, 1500);
  };

  const reset = () => {
    setUserIndex(u => u + 1);
    setCurrentIdx(0);
    setAnswer(default_answers[0]);
    setAnswers({});
    setResult(null);
    setCopied(false);
    setShowRawJson(false);
    setFiles({ toothpastes: true, tpmConf: true, pickstats: true });
  };

  return (
    <div style={{ 
      maxWidth: '720px', 
      width: '100%', 
      margin: '20px auto', 
      padding: '24px', 
      fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif', 
      border: '1px solid #e2e8f0', 
      borderRadius: '12px', 
      boxSizing: 'border-box',
      backgroundColor: '#ffffff',
      boxShadow: '0 4px 6px -1px rgba(0,0,0,0.1)'
    }}>
      <div style={{ 
        display: 'flex', 
        justifyContent: 'space-between', 
        borderBottom: '2px solid #f1f5f9', 
        paddingBottom: '12px', 
        marginBottom: '20px',
        alignItems: 'center'
      }}>
        <div>
          <h3 style={{ margin: 0, fontSize: '20px', fontWeight: 'bold', color: '#0f172a' }}>🪥 TPM Dashboard</h3>
          <span style={{ fontSize: '12px', color: '#64748b' }}>Toothpaste Picking Manager</span>
        </div>
        <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
          <span style={{ fontSize: '12px', fontWeight: 'bold', background: '#e2e8f0', padding: '4px 10px', borderRadius: '12px', color: '#475569' }}>
            ID: #{String(userIndex).padStart(4, '0')}
          </span>
          <a 
            href="https://github.com/notlibrary/tpm/releases" 
            target="_blank" 
            rel="noreferrer" 
            style={{ fontSize: '12px', color: '#3b82f6', textDecoration: 'none', fontWeight: '500' }}
          >
            TPM Releases ↗
          </a>
        </div>
      </div>

      {!loading && !result && (
        <form onSubmit={handleSubmit} style={{ width: '100%' }}>
          {currentIdx === 0 && (
            <div style={{ 
              background: '#f0f9ff', 
              borderLeft: '4px solid #3b82f6', 
              padding: '12px 16px', 
              borderRadius: '0 8px 8px 0', 
              marginBottom: '20px', 
              fontSize: '13px', 
              color: '#0c4a6e', 
              lineHeight: '1.6', 
              whiteSpace: 'pre-line',
              border: '1px solid #bae6fd',
              borderLeftWidth: '4px'
            }}>
              {welcome_msg}
            </div>
          )}

          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
            <span style={{ fontSize: '13px', color: '#64748b', fontWeight: '500' }}>
              Question {currentIdx + 1} of {questions.length}
            </span>
            <span style={{ fontSize: '11px', background: '#f1f5f9', padding: '2px 8px', borderRadius: '10px', color: '#64748b' }}>
              {Math.round(((currentIdx + 1) / questions.length) * 100)}% complete
            </span>
          </div>
          <div style={{ 
            width: '100%', 
            height: '4px', 
            background: '#e2e8f0', 
            borderRadius: '2px', 
            marginBottom: '16px',
            overflow: 'hidden'
          }}>
            <div style={{ 
              width: `${((currentIdx + 1) / questions.length) * 100}%`, 
              height: '100%', 
              background: 'linear-gradient(90deg, #3b82f6, #10b981)',
              transition: 'width 0.3s ease'
            }} />
          </div>
          
          <label style={{ 
            fontWeight: '600', 
            display: 'block', 
            marginBottom: '16px', 
            fontSize: '17px', 
            lineHeight: '1.5',
            color: '#0f172a'
          }}>
            {questions[currentIdx]}
          </label>
          
          {currentIdx === 1 ? (
            <div style={{ 
              display: 'flex', 
              flexDirection: 'column', 
              gap: '12px', 
              marginBottom: '20px',
              background: '#f8fafc',
              padding: '16px',
              borderRadius: '8px',
              border: '1px solid #e2e8f0'
            }}>
              <label style={{ 
                display: 'flex', 
                gap: '10px', 
                cursor: 'pointer', 
                alignItems: 'center',
                padding: '8px 12px',
                borderRadius: '6px',
                transition: 'background-color 0.2s',
                background: files.toothpastes ? '#e0f2fe' : 'transparent'
              }}>
                <input 
                  type="checkbox" 
                  checked={files.toothpastes} 
                  onChange={() => handleCheckboxChange('toothpastes')} 
                  style={{ width: '18px', height: '18px', cursor: 'pointer' }}
                />
                <span style={{ fontFamily: 'monospace', fontSize: '14px' }}>~/tpm/toothpastes</span>
                <span style={{ fontSize: '12px', color: '#64748b', marginLeft: 'auto' }}>Recommendations in CSV Format</span>
              </label>
              <label style={{ 
                display: 'flex', 
                gap: '10px', 
                cursor: 'pointer', 
                alignItems: 'center',
                padding: '8px 12px',
                borderRadius: '6px',
                transition: 'background-color 0.2s',
                background: files.tpmConf ? '#e0f2fe' : 'transparent'
              }}>
                <input 
                  type="checkbox" 
                  checked={files.tpmConf} 
                  onChange={() => handleCheckboxChange('tpmConf')} 
                  style={{ width: '18px', height: '18px', cursor: 'pointer' }}
                />
                <span style={{ fontFamily: 'monospace', fontSize: '14px' }}>~/tpm/tpm.conf</span>
                <span style={{ fontSize: '12px', color: '#64748b', marginLeft: 'auto' }}>Environmental Configuration</span>
              </label>
              <label style={{ 
                display: 'flex', 
                gap: '10px', 
                cursor: 'pointer', 
                alignItems: 'center',
                padding: '8px 12px',
                borderRadius: '6px',
                transition: 'background-color 0.2s',
                background: files.pickstats ? '#e0f2fe' : 'transparent'
              }}>
                <input 
                  type="checkbox" 
                  checked={files.pickstats} 
                  onChange={() => handleCheckboxChange('pickstats')} 
                  style={{ width: '18px', height: '18px', cursor: 'pointer' }}
                />
                <span style={{ fontFamily: 'monospace', fontSize: '14px' }}>~/tpm/pickstats</span>
                <span style={{ fontSize: '12px', color: '#64748b', marginLeft: 'auto' }}>Statistical initializer</span>
              </label>
            </div>
          ) : (
            <input 
              type="text" 
              value={answer} 
              onChange={e => setAnswer(e.target.value)} 
              autoFocus 
              style={{ 
                width: '100%', 
                padding: '12px', 
                marginBottom: '20px', 
                boxSizing: 'border-box', 
                border: '2px solid #e2e8f0', 
                borderRadius: '8px', 
                fontSize: '15px',
                transition: 'border-color 0.2s',
                outline: 'none'
              }}
              onFocus={e => e.target.style.borderColor = '#3b82f6'}
              onBlur={e => e.target.style.borderColor = '#e2e8f0'}
            />
          )}
          
          <button 
            type="submit" 
            style={{ 
              width: '100%', 
              padding: '14px', 
              background: currentIdx === questions.length - 1 
                ? 'linear-gradient(135deg, #3b82f6, #8b5cf6)' 
                : '#0f172a',
              color: '#fff', 
              border: 'none', 
              borderRadius: '8px', 
              cursor: 'pointer', 
              fontSize: '16px', 
              fontWeight: 'bold',
              transition: 'transform 0.2s, box-shadow 0.2s',
              boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
            }}
            onMouseEnter={e => e.currentTarget.style.transform = 'scale(1.01)'}
            onMouseLeave={e => e.currentTarget.style.transform = 'scale(1)'}
          >
            {currentIdx === questions.length - 1 ? '🤖 Generate with AI' : 'Next →'}
          </button>
          
          <div style={{ marginTop: '12px', fontSize: '12px', color: '#94a3b8', textAlign: 'center' }}>
            {currentIdx + 1} of {questions.length} questions
          </div>
        </form>
      )}

      {loading && (
        <div style={{ textAlign: 'center', margin: '40px 0' }}>
          <div style={{ 
            display: 'inline-block',
            width: '48px',
            height: '48px',
            border: '4px solid #e2e8f0',
            borderTop: '4px solid #3b82f6',
            borderRadius: '50%',
            animation: 'spin 1s linear infinite'
          }} />
          <p style={{ marginTop: '16px', color: '#64748b', fontWeight: '500' }}>🤖 Generating TPM files...</p>
          <p style={{ fontSize: '13px', color: '#94a3b8' }}>Creating configuration, toothpaste list, and binary stats</p>
          <style>
            {`
              @keyframes spin {
                0% { transform: rotate(0deg); }
                100% { transform: rotate(360deg); }
              }
            `}
          </style>
        </div>
      )}

      {result && (
        <div style={{ width: '100%' }}>
          <div style={{ 
            display: 'flex', 
            justifyContent: 'space-between', 
            alignItems: 'center', 
            marginBottom: '16px',
            paddingBottom: '12px',
            borderBottom: '1px solid #e2e8f0'
          }}>
            <div>
              <h4 style={{ color: '#065f46', margin: 0, fontSize: '18px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <span>✅</span> Files Generated
              </h4>
              <span style={{ fontSize: '12px', color: '#64748b' }}>User #{String(userIndex).padStart(4, '0')}</span>
            </div>
            <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
              <button 
                type="button"
                onClick={() => setShowRawJson(!showRawJson)}
                style={{ 
                  padding: '6px 12px', 
                  background: showRawJson ? '#f59e0b' : '#64748b', 
                  color: '#fff', 
                  border: 'none', 
                  borderRadius: '4px', 
                  cursor: 'pointer', 
                  fontSize: '12px', 
                  fontWeight: 'bold',
                  transition: 'background-color 0.2s'
                }}
              >
                {showRawJson ? '📋 Hide JSON' : '📋 Show JSON'}
              </button>
              <button 
                type="button"
                onClick={handleCopyToClipboard}
                style={{ 
                  padding: '6px 12px', 
                  background: copied ? '#059669' : '#3b82f6', 
                  color: '#fff', 
                  border: 'none', 
                  borderRadius: '4px', 
                  cursor: 'pointer', 
                  fontSize: '12px', 
                  fontWeight: 'bold', 
                  transition: 'background-color 0.2s',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '4px'
                }}
              >
                {copied ? '✓ Copied!' : '📋 Copy JSON'}
              </button>
            </div>
          </div>

          {showRawJson && (
            <div style={{ 
              marginBottom: '16px',
              padding: '12px',
              background: '#1e293b',
              borderRadius: '8px',
              overflow: 'auto',
              maxHeight: '200px'
            }}>
              <pre style={{ 
                margin: 0, 
                color: '#e2e8f0', 
                fontSize: '11px', 
                fontFamily: 'monospace',
                whiteSpace: 'pre-wrap'
              }}>
                {JSON.stringify(answers, null, 2)}
              </pre>
            </div>
          )}
          
          {Object.entries(result).map(([k, v]) => {
            if (!v) return null;
            const key = k as keyof ResultType;
            const value = result[key];
            if (!value) return null;
            
            return (
              <div key={k} style={{ marginTop: '12px' }}>
                <div style={{ 
                  display: 'flex', 
                  alignItems: 'center', 
                  gap: '8px', 
                  marginBottom: '4px'
                }}>
                  <span style={{ 
                    fontSize: '12px', 
                    fontFamily: 'monospace', 
                    fontWeight: 'bold',
                    color: '#0f172a',
                    background: '#f1f5f9',
                    padding: '2px 8px',
                    borderRadius: '4px'
                  }}>
                    ~/tpm/{k}
                  </span>
                  <span style={{ 
                    fontSize: '10px', 
                    color: '#64748b',
                    background: '#e2e8f0',
                    padding: '1px 6px',
                    borderRadius: '3px'
                  }}>
                    {k === 'pickstats' ? 'binary (C struct)' : `${value.toString().split('\n').length} lines`}
                  </span>
                </div>
                <pre style={{ 
                  background: '#0f172a', 
                  color: k === 'pickstats' ? '#fcd34d' : '#a7f3d0', 
                  padding: '12px', 
                  borderRadius: '8px', 
                  overflowX: 'auto', 
                  margin: 0, 
                  fontSize: k === 'pickstats' ? '11px' : '12px', 
                  whiteSpace: 'pre-wrap',
                  fontFamily: 'monospace',
                  border: '1px solid #1e293b',
                  maxHeight: k === 'pickstats' ? '100px' : '250px',
                  overflowY: 'auto',
                  wordBreak: 'break-all'
                }}>
                  {value}
                </pre>
              </div>
            );
          })}
          
          <div style={{ marginTop: '24px', display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
            <button 
              type="button" 
              onClick={downloadAll} 
              style={{ 
                flex: 1,
                minWidth: '120px',
                padding: '14px', 
                background: 'linear-gradient(135deg, #8b5cf6, #6d28d9)', 
                color: '#fff', 
                border: 'none', 
                borderRadius: '8px', 
                cursor: 'pointer', 
                fontSize: '16px', 
                fontWeight: 'bold',
                transition: 'transform 0.2s',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: '8px'
              }}
              onMouseEnter={e => e.currentTarget.style.transform = 'scale(1.01)'}
              onMouseLeave={e => e.currentTarget.style.transform = 'scale(1)'}
            >
              📦 Download All Files
            </button>
            <button 
              type="button" 
              onClick={reset} 
              style={{ 
                flex: 1,
                minWidth: '120px',
                padding: '14px', 
                background: 'linear-gradient(135deg, #10b981, #059669)', 
                color: '#fff', 
                border: 'none', 
                borderRadius: '8px', 
                cursor: 'pointer', 
                fontSize: '16px', 
                fontWeight: 'bold',
                transition: 'transform 0.2s'
              }}
              onMouseEnter={e => e.currentTarget.style.transform = 'scale(1.01)'}
              onMouseLeave={e => e.currentTarget.style.transform = 'scale(1)'}
            >
              👤 Next User
            </button>
          </div>
        </div>
      )}
    </div>
  );
}