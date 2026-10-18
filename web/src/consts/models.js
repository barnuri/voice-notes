export const MODELS = [
  {
    id: 'ivrit/ivrit-large-v3-turbo',
    title: 'ivrit.ai Hebrew',
    description: 'Whisper large-v3-turbo fine-tuned on Hebrew by ivrit.ai. Fast and accurate for Hebrew speech.',
  },
  {
    id: 'ivrit_large/ivrit-large-v3',
    title: 'ivrit.ai Hebrew large',
    description: 'Full Whisper large-v3 fine-tuned on Hebrew by ivrit.ai. Slower, may be more accurate.',
  },
  {
    id: 'whisper/whisper-large-v3',
    title: 'Whisper large-v3',
    description: 'OpenAI multilingual model at full precision. Good for English and mixed speech.',
  },
  {
    id: 'parakeet/mlx-community/parakeet-tdt-0.6b-v2',
    title: 'Parakeet English',
    description: 'NVIDIA Parakeet TDT 0.6B v2 on MLX. English only, fastest and most accurate for English.',
  },
];

export const DEFAULT_MODEL_ID = 'ivrit/ivrit-large-v3-turbo';
