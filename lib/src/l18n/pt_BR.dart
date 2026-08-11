import 'dart:core';

class pt_BR {
  static Map<String, String> keys() {
    return {
      /// common
      'yes': 'Sim',
      'no': 'Não',
      'cancel': "Cancelar",
      'OK': "OK",
      'reset': "Reset",
      'success': "Successo",
      'error': "Erro",
      'failed': "Falhou",
      'reload': 'Recarregar',
      'noMoreData': 'Sem mais',
      'noData': 'Sem dados',
      'operationFailed': 'Falha na opreção',
      'needLoginToOperate': 'Precisa de login para operar',
      'hasCopiedToClipboard': "Copiado para aréa de transferência",
      'platformNotSupported': "Plataforma atual não suportada",
      'networkError': "Erro na conexão com a rede",
      'systemError': "Erro no sistema",
      'invalid': "Inválido",
      'internalError': "Erro interno",
      'you': 'Você',
      'retryHint': 'Please retry after refresh',
      'stop': 'Stop',
      'attention': 'Attention',
      'jump': 'Jump',
      'resetReadProgress': 'Reset Read Progress',
      'deleteAll': 'Delete All',
      'connectionTimeoutHint': 'Network connect timeout',
      'receiveDataTimeoutHint': 'Network receive data timeout',
      'archiveError': 'Download Archive Error',
      'edit': 'Edit',
      'confirmDestructiveActions': 'Confirmar ações destrutivas',
      'confirmDestructiveActionsHint':
          'Mostrar um diálogo de confirmação antes de ações destrutivas, como excluir tarefas ou baixar novamente na página de downloads',

      'home': "Home",
      'gallery': "Galeria",
      'setting': 'Configuração',

      /// schedule
      'dawnOfaNewDay': 'It is the dawn of a new day!',
      'encounterMonster': 'You have encountered a monster!',
      'encounterMonsterHint': 'Click to fight in the HentaiVerse.',

      /// unlock page
      'localizedReason': 'Por favor, autentique-se para continuar',
      'tap2Auth': 'Toque para autentique-se',
      'authHint': 'Auth to continue',
      'passwordErrorHint': 'Password error, please try again',

      /// start page
      'TapAgainToExit': 'Toque novamente para sair',

      /// update dialog
      'availableUpdate': 'Atualização disponível!',
      'LatestVersion': 'Latest Ver',
      'CurrentVersion': 'Current Ver',
      'check': 'Checar',
      'dismiss': 'Dispensar',

      /// login page
      'login': 'Login',
      'notLoggedIn': 'Login',
      'logout': 'Logout',
      'passwordLogin': 'Senha de login',
      'cookieLogin': 'Cookie de login',
      'useWebview': 'Use Webview',
      'skipCookieVerification': 'Skip Verification',
      'youHaveLoggedInAs': 'Olá:   ',
      'cookieIsBlack': 'Cookie está preto/vazio',
      'cookieFormatError': 'Error no formato do cookie',
      'invalidCookie': 'falha no login ou cookie inválido',
      'loginFail': 'Falha no login',
      'userName': 'Nome de usuário',
      'EHUser': 'Usuário EH',
      'password': 'Senha',
      'needCaptcha':
          'Precisa do captcha, por favor fassa login via cookie ou pela web de novo.',
      'userNameOrPasswordMismatch': 'Nome de usuáriio e/ou senha incorreto(s)',
      'copyCookies': 'Copiar cookies',
      'tap2Copy': 'Toque para copiar',
      'webLoginIsDisabled': 'Login pela Web está disabilitado no desktop',
      'loginSuccess': 'Login feito com sucesso',
      'userNameFormHint': 'Try with cookie in case of Sad Panda',
      'tap2Login': 'Log In',
      'parse': 'parse',
      'igneousHint': 'igneous(EX required)',
      'refreshIgneousFailed': 'Refresh Igneous Failed',

      /// request
      'sadPanda':
          'Sad Panda(no data). Refer: https://github.com/jiangtian616/JHenTai/wiki/Common-Questions',
      'sadPandaReferLink':
          'https://github.com/jiangtian616/JHenTai/wiki/Common-Questions',

      /// gallery card
      'filtered': 'Filtered',

      /// gallery page
      'getGallerysFailed': "Falha ao obter galerias",
      'refreshGalleryFailed': 'Falha ao Atualizar galerias',
      'tabBarSetting': 'Opções da barra de abas',
      'jumpPageTo': 'Pular para à página',
      'range': 'Alcance',
      'current': 'Atual',
      'galleryUrlDetected':
          'URL de galeria encontrada na área de transferência',
      'galleryUrlDetectedHint': 'Toque para entrar na página de detalhes',

      /// details page
      'read': 'Ler',
      'download': 'Baixar',
      'favorite': 'Favorito',
      'rating': 'Avaliação',
      'torrent': 'Torrent',
      'archive': 'Arquivo',
      'statistic': 'Estatística',
      'similar': 'Similar',
      'downloading': "Baixando",
      'resume': "Retomar",
      'pause': 'Pausar',
      'finished': 'Finalizado',
      'update': 'Atualizar',
      'submit': 'Enviar',
      'chooseFavorite': 'Escolhher favorito',
      'asYourDefault': 'As Default',
      'Note': 'Note',
      'addNoteHint': 'Choose a slot before adding note',
      'uploader': 'Uploader',
      'allComments': 'Todos os comentários',
      'noComments': 'Sem comentários',
      'lastEditedOn': 'Última edição em',
      'getGalleryDetailFailed': 'Falha ao obter detalhes da galeria',
      'cloudflare403':
          'You have been restricted by Cloudflare from making network requests. Please try switching networks or using another login method.',
      'invisible2User': 'Esta Galeria é invisível para você',
      'invisibleHints': 'Esta galeria está indisponível ou foi removida.',
      'copyRightHints':
          'Esta galeria está indisponível devido a uma reivindicação de direitos autorais por ',
      'refreshGalleryDetailsFailed': 'Falha ao atualizar detalhes da galeria',
      'failToGetThumbnails': "Falha ao obter miniaturas",
      'favoriteGallerySuccess': "Favorite Gallery Success",
      'favoriteGalleryFailed': "Falha na galeria Favorita",
      'removeFavoriteSuccess': "Remove Favorite Success",
      'removeFavoriteFailed': "Remove Favorite Failed",
      'getGalleryFavoriteInfoFailed': 'Get gallery favorite info failed',
      'favoriteNoteSlotFullHint':
          'Favorite note slot is full, please delete some notes first',
      'ratingSuccess': 'Rating Success',
      'ratingFailed': 'Falha na avaliação',
      'voteTagFailed': 'Falha na tag de votação',
      'beginToDownload': 'Começar a baixar',
      'resumeDownload': 'Retomar',
      'pauseDownload': 'Pausar',
      'addNewTagSetSuccess': 'Novo conjunto de tags adicionado com sucesso',
      'addNewWatchedTagSetSuccess':
          'Novo conjunto de tags adicionado com sucesso',
      'addNewHiddenTagSetSuccess':
          'Novo conjunto de tags ocultas adicionado com sucesso',
      'addNewTagSetSuccessHint':
          'Você pode verificar suas tags em Configurações->EH->My Tags',
      'addNewTagSetFailed': 'Falha ao adicionar novo conjunto de tags',
      'VisitorStatistics': 'Estatísticas do visitante',
      'invisible2UserWithoutDonation':
          'As estatísticas desta galeria são invisíveis para os usuários sem doação',
      'getGalleryStatisticsFailed': 'Falha ao obter estatísticas da galeria',
      'totalVisits': 'Total de visitas',
      'visits': 'Visitas',
      'imageAccesses': 'Acessos à imagem',
      'period': 'Período',
      'ranking': 'Classificação',
      'score': 'Pontuação',
      'NotOnTheList': 'Não está na lista',
      'getGalleryArchiveFailed': 'Falha ao obter arquivo da galeria',
      'parseGalleryArchiveFailed':
          'Falha na análise, certifique-se de que seu [Archiver Settings] em e-hentai é [Manual Select, Manual Start (Default)]',
      'original': 'Original',
      'resample': 'Redimensionamento',
      'beginToDownloadArchive': 'Começar a baixar o arquivo',
      'beginToDownloadArchiveHint':
          'Você pode verificar o progresso em Baixar -> Arquivo',
      'updateGalleryError': 'Erro ao atualizar galeria',
      'thisGalleryHasANewVersion': 'Nova versão desta galeria disponível',
      'hasUpdated': 'Atualizado',
      'unpackingArchiveError': 'Unpacking archive error',
      'failedToDealWith': 'Falha ao lidar com',
      'hasDownloaded': 'Baixado',
      '410Hints':
          'Você registrou muitos bytes baixados neste arquivo e precisa desbloquear novamente este arquivo para continuar.',
      '429Hints':
          'Too many download requests! You\'d better decrease your archive download concurrency.',
      'getUnpackedImagesFailedMsg':
          'JHenTai não pode carregar imagens deste arquivo, por favor verifique seu arquivo local.',
      'getGalleryTorrentsFailed': 'Falha ao obter torrents',
      'chooseArchive': 'Escolher Arquivo',
      'tagSetExceedLimit':
          'No more tags can be added because you have reach the limit',
      'useTranslation': 'Use Translation',
      'addTagSuccess': 'Add Tag Success',
      'addTagFailed': 'Add Tag Failed',
      'parentGallery': 'Parent',
      'blockUploaderLocally': 'Block user locally',
      'block': 'Block',

      /// detail dialog
      'galleryUrl': 'Gallery Url',
      'title': 'Title',
      'japaneseTitle': 'Japanese Title',
      'category': 'Category',
      'publishTime': 'Publish Time',
      'pageCount': 'Page Count',
      'favoriteCount': 'Favorite Count',
      'ratingCount': 'Rating Count',

      /// comment page
      'newComment': 'Novo comentário',
      'updateComment': 'Update Comment',
      'commentTooShort': 'O comentário é muito curto',
      'sendCommentFailed': 'Falha ao enviar comentário',
      'voteCommentFailed': 'Falha ao votar cometário',
      'voteCommentFailedHint':
          'Tente puxar para baixo para atualizar a página de detalhes primeiro',
      'unknownUser': 'Usuário desconhecido',
      'atLeast3Characters': 'Pelo menos 3 caracteres',
      'noJHenTaiHints': 'Please don\'t mention JHenTai, thanks',
      'blockUser': 'Block user',

      /// EHImage
      'reloadImage': "Recarregar imagem",

      /// read page
      'parsingPage': "Página de análise",
      'parsingURL': "URL de análise",
      'parsePageFailed': "Falha na análise da página",
      'parseURLFailed': "Falha na analise da URL",
      'loading': "Caregando",
      'paused': 'Pausar',
      'exceedImageLimits': "Limite de imagens excedido",
      'ehServerError':
          'An error occurred due to EH\'s server, please try again later',
      'unsupportedImagePageStyle':
          "JHenTai não suporta Multi-Page Viewer (MPV), por favor mude para o estilo padrão em e-hentai.org",
      'toNext': 'Para o próximo',
      'toPrev': 'Para anterior',
      'back': 'Voltar',
      'toggleMenu': 'Alternar menu',
      'share': 'Compartilhar',
      'copyImage': 'Copiar imagem',
      'save': 'Salvar em imagens',
      'copyEHPageUrl': 'Copiar URL da página E-hentai',

      /// setting page
      'account': 'Conta',
      'EH': 'EH',
      'style': 'Estilo',
      'preference': 'Preference',
      'network': 'Network',
      'performance': 'Performance',
      'mouseWheel': 'Roda do mouse',
      'advanced': 'Avançado',
      'cloud': 'Cloud',
      'security': 'Segurança',
      'about': 'Sobre',
      'accountSetting': 'Configurações da conta',
      'styleSetting': 'Configurações de estilo',
      'advancedSetting': 'Configurações avançadas',
      'securitySetting': 'Configurções de segurança',
      'ehSetting': 'Configuração do site EH',
      'readSetting': 'Configurações de leitura',
      'preferenceSetting': 'Preference Setting',
      'downloadSetting': 'Configurações de download',
      'networkSetting': 'Configurações de Network',
      'performanceSetting': 'Performance Setting',
      'inferenceSetting': 'Configurações de inferência',
      'mouseWheelSetting': 'Configurações da roda do mouse',

      /// eh setting page
      'site': 'Site',
      'redirect2Eh': 'Redirecionar para EH, se disponível',
      'redirect2EhHint':
          'Try to load gallery detail page from EH site first to get better network performance',
      'redirectAllGallery': 'Redirect all gallery to EH',
      'imDonorHint':
          'If you are a donor, you can turn this on to help you access gallerys in EX site',
      'profileSetting': 'Profile Setting',
      'chooseProfileHint': 'Choose profile used in JHenTai',
      'siteSetting': 'Configuração do site',
      'siteSettingHint': 'Edit site setting in e-hentai',
      'showCookie': 'Cookie',
      'redirect2EH': 'Redirecionar para o site EH, se disponível',
      'redirect2Hints': 'Tentar analisar o site EH primeiro',
      'pleaseLogInToOperate': 'Faça login para operar',
      'imageLimits': 'Image Quota',
      'resetCost': 'Long press to reset, cost',
      'assets': 'Assets',
      'isNotDonator': 'Non-donators can\'t view the quota',
      'fetchImageQuotaFailed': 'Fetch image quota failed',

      /// tag setting page
      'myTags': 'Minhas Tags',
      'myTagsHint': 'gerenciar tags assistidas e ocultas',
      'localTags': 'Local Tags',
      'localTagsHint': 'Extra filter tags',
      'localTagsHint2': 'Gallerys with these tags will be hidden',
      'addLocalTags': 'Add Tags',
      'hidden': 'Escondido',
      'nope': 'Nope(Não)',
      'getTagSetFailed': 'Falha ao obter conjunto de tags',
      'updateTagSetFailed': 'Falha na atualização do conjunto de tags',
      'updateTagFailed': 'Falha na atualização do conjunto de tags',
      'deleteTagSuccess': 'Falha na atualização do conjunto de tags',
      'deleteTagFailed': 'Falha ao excluir conjunto de tags',
      'addLocalTagHint': 'Search to add new tag',

      /// Profile Setting page
      'selectedProfile': 'Selected Profile',
      'resetIfSwitchSite': 'Will be reset if switch site',

      /// add host mapping dialog
      'addHostMapping': 'Add Host Mapping',

      /// Layout
      'layoutMode': 'Modo de layout',
      'mobileLayoutV2Name': 'Celular',
      'mobileLayoutV2Desc': 'Uma coluna',
      'mobileLayoutName': 'Celular(antigo)',
      'mobileLayoutDesc': 'Manutenção interrompida',
      'tabletLayoutV2Name': 'Tablet',
      'tabletLayoutV2Desc': 'Duas colunas',
      'tabletLayoutName': 'Tablet(antigo)',
      'tabletLayoutDesc': 'Manutenção interrompida',
      'desktopLayoutName': 'Desktop',
      'desktopLayoutDesc':
          'Duas colunas com barra de abas na esquerda, suporte a teclado',

      /// style setting page
      'enableTagZHTranslation': 'Traduzir nome da tag para Chinês',
      'version': 'Versão',
      'downloadTagTranslationHint': 'Baixando dados..., baixado: ',
      'zhTagSearchOrderOptimization':
          'Chinese Tag Auto-Completion Ordering Rule',
      'zhTagSearchOrderOptimizationHint':
          'Intelligent sorting by default and sort by frequency if enabled',
      'themeMode': 'Tema',
      'dark': 'Escuro',
      'light': 'Claro',
      'followSystem': 'Seguir o sistema',
      'themeColor': 'Theme Color',
      'themeColorFixedOnApple': 'Cor de destaque fixa no macOS / iOS',
      'appleVisualStyle': 'Estilo visual Apple',
      'appleVisualStyleHint': 'Ativar a interface redesenhada no estilo Apple',
      'listStyle': 'Estilo da lista da galeria',
      'flat': 'Reto',
      'flatWithoutTags': 'Reto(Sem tags)',
      'listWithoutTags': 'Cartão(Sem tags)',
      'listWithTags': 'Cartão',
      'waterfallFlowSmall': 'Waterfall Flow (Small)',
      'waterfallFlowMedium': 'Waterfall Flow (Medium)',
      'waterfallFlowBig': 'Waterfall Flow (Big)',
      'crossAxisCountInWaterFallFlow': 'Waterfall Flow Column count',
      'pageListStyle': 'Gallery List Style (Page)',
      'crossAxisCountInGridDownloadPageForGroup':
          'Download Page Grid Column Count(Group)',
      'crossAxisCountInGridDownloadPageForGallery':
          'Download Page Grid Column Count(Gallery)',
      'crossAxisCountInDetailPage': 'Detail Page Thumbnail Column Count',
      'global': 'Global',
      'auto': 'Auto',
      'moveCover2RightSide': 'Mover a tampa para o lado direito',
      'coverStyle': 'Estilo da tampa',
      'cover': 'Tampa',
      'adaptive': 'Adaptativo',
      'simpleDashboardMode': 'Simple Home Page',
      'simpleDashboardModeHint': 'Hide Ranklist and Popular',
      'hideBottomBar': 'Ocultar barra inferior',
      'hideScroll2TopButton': 'Hide Scroll to Top Button',
      'whenScrollUp': 'When Scroll Up',
      'whenScrollDown': 'When Scroll Down',
      'preloadGalleryCover': 'Preload gallery cover',
      'preloadGalleryCoverHint':
          'Preload the covers of galleries that are not yet displayed on the page',
      'enableSwipeBackGesture': 'Enable Swipe Back Gesture',
      'enableLeftMenuDrawerGesture': 'Enable Left Menu Drawer Gesture',
      'enableQuickSearchDrawerGesture':
          'Ativar pesquisa rápida com gesto de gaveta',
      'drawerGestureEdgeWidth': 'Drawer Gesture Edge Width',
      'alwaysShowScroll2TopButton':
          'Sempre mostrar o botão de rolagem para cima',
      'enableDefaultFavorite': 'Enable Default Favorite',
      'enableDefaultFavoriteHint': 'Long press to re-select',
      'enableDefaultTagSet': 'Enable Default Tag Set',
      'enableDefaultTagSetHint': 'Long press to re-select',
      'disableDefaultTagSetHint': 'Select manually',
      'launchInFullScreen': 'Launch In Full Screen',
      'launchInFullScreenHint': 'Switch manually by F11',
      'disableDefaultFavoriteHint': 'Select manually',
      'searchBehaviour': 'Search Behaviour',
      'inheritAll': 'Inherit All',
      'inheritAllHint': 'Use last search options for next search',
      'inheritPartially': 'Inherit Partially',
      'inheritPartiallyHint':
          'Use last search options for next search(except language and category)',
      'none': 'None',
      'noneHint': 'Use default search options for next search',
      'showAllGalleryTitles': 'Show All Gallery Titles',
      'showAllGalleryTitlesHint':
          'Show both original and japanese titles if available',
      'showGalleryTagVoteStatus': 'Show Gallery Tag Vote Status',
      'showGalleryTagVoteStatusHint':
          'Include confidence, skepticism and incorrect',
      'showComments': 'Show Comments',
      'showAllComments': 'Show All Comments',
      'showAllCommentsHint':
          'By default only the 45 highest scoring and 5 most recent comments will be shown',
      'addTag': 'Add Tag',
      'addTagHint': 'Enter new tags, separated with comma',

      /// theme color setting page
      'themeColorSettingHint':
          'Assign different color for light and dark theme',
      'preview': 'Preview',
      'preset': 'Preset',
      'custom': 'Custom',

      /// performance setting page
      'maxGalleryNum4Animation':
          'Max Gallery Num For List Animation in Download page',
      'maxGalleryNum4AnimationHint':
          'Disable animation for groups which have more gallerys than this value(for list style)',
      'enableCoverDecodeOptimization': 'Otimização de decodificação de capas',
      'enableCoverDecodeOptimizationHint':
          'Decodifica as capas em um tamanho próximo ao exibido, em vez da resolução nativa. Reduz tempo de decodificação e uso de memória ao navegar pelas grades, com pequena perda de qualidade.',

      /// mouse wheel setting page
      'wheelScrollSpeed': 'Velocidade de rolagem',
      'ineffectiveInGalleryPage': 'Ineficaz na página da galeria agora.',

      /// advanced setting page
      'readerPerformanceExperiments': 'Experimentos de desempenho de leitura',
      'readerEngine2': 'Reader Engine 2.0',
      'readerEngine2Hint':
          'Prioriza páginas próximas com base na área visível e na direção da leitura.',
      'performanceGovernor': 'Performance Governor',
      'performanceGovernorHint':
          'Monitora o tempo dos quadros e reduz a pré-carga e a concorrência quando há travamentos contínuos.',
      'progressiveImagePipeline': 'Pipeline progressivo de imagens',
      'progressiveImagePipelineHint':
          'Mostra primeiro a miniatura e depois a substitui pela imagem original.',
      'enableDomainFronting': 'Ativar frente de Domínio',
      'bypassSNIBlocking': 'Ignorar bloqueio de SNI',
      'hostMapping': 'Mapeamento de host',
      'hostMappingHint': 'Usado para frente de domínio',
      'proxyAddress': 'Endereço de proxy',
      'proxyAddressHint':
          'Se você usa servidor proxy, certifique-se de configurá-lo corretamente',
      'saveSuccess': 'Salvo com sucesso',
      'saveFailed': 'Save failed',
      'updateSuccess': 'Atualizado com sucesso',
      'connectTimeout': 'Tempo limite de conexão',
      'receiveTimeout': 'Tempo limite de recebimento de dados',
      'enableSmartCache': "Cache Inteligente",
      'enableSmartCacheHint':
          "Quando ativado, mantém as páginas e imagens vistas pelo período definido; desativado mantém apenas um cache de curta duração",
      'smartCacheRetention': "Retenção do cache",
      'smartCacheRetentionHint':
          "Caches mais antigos que isso são limpos automaticamente",
      'smartCacheMaxSize': "Limite de espaço do cache",
      'smartCacheMaxSizeHint':
          "O cache é limpo automaticamente ao exceder este limite",
      'smartCacheEvictPolicy': "Política de limpeza",
      'smartCacheEvictPolicyHint':
          "Quais entradas são removidas primeiro ao atingir o limite",
      'smartCacheEvictByAddedDate': "Por data de adição",
      'smartCacheEvictByUsageFrequency': "Por frequência de uso",
      'unlimited': "Ilimitado",
      'cacheSize': "Tamanho atual do cache",
      'oneMinute': '1 Minuto',
      'tenMinute': '10 Minutos',
      'oneHour': '1 Hora',
      'oneDay': '1 Dia',
      'threeDay': '3 Dias',
      'enableLogging': 'Ativar registro(log)',
      'enableVerboseLogging': 'Ativar registro(log) detalhado',
      'openLog': 'Abrir registro(log)',
      'clearLogs': 'Limpar registros(logs)',
      'longPress2Clear': 'Pressione e segure para limpar',
      'checkUpdateAfterLaunchingApp': 'Buscar atualizações após abrir o app',
      'checkClipboard':
          'Verificar se há URL de Galeria na área de transferência',
      'clearSuccess': 'Limpado com Sucesso',
      'superResolution': 'Image Super Resolution',
      'inferenceBackend': 'Backend de inferência',
      'inferenceRefresh': 'Atualizar',
      'inferenceModeSection': 'Modo',
      'inferenceManualSection': 'Backend manual',
      'inferenceDetectionSection': 'Detecção',
      'inferenceModelSection': 'Integração de modelos',
      'inferenceModeAuto': 'Automático',
      'inferenceModeManual': 'Manual',
      'inferenceModeCpu': 'CPU',
      'inferencePreferredBackend': 'Backend preferido',
      'inferenceDetectedDevice': 'Dispositivo detectado',
      'inferenceDeviceNotDetected':
          'Não detectado (preenchido após integrar modelos)',
      'inferenceDomainOcr': 'Tradução de imagem (OCR)',
      'inferenceDomainSuperResolution': 'Super resolução',
      'inferenceEnableNnapi': 'Ativar aceleração NNAPI',
      'inferenceEnableNnapiHint':
          'Usa NPU/GPU/DSP em aparelhos Android compatíveis; volta para CPU automaticamente.',
      'inferenceEnableCpuFallback': 'Fallback para CPU',
      'inferenceEnableCpuFallbackHint':
          'Usa CPU quando o backend selecionado não estiver disponível.',
      'inferenceEngineOcr': 'Tradução de imagem/texto',
      'inferenceEngineSuperResolution': 'Upscaling de imagem',
      'inferenceModelReady': 'Pronto',
      'inferenceModelNotIntegrated':
          'A inferência não está pronta; veja os detalhes nas configurações',
      'inferenceOcrModel': 'OCR multilíngue PP-OCRv6 small',
      'inferenceOcrLanguageAuto':
          'Reconhece automaticamente chinês, japonês, inglês e 50 idiomas',
      'inferenceSuperResolutionModel':
          'Modelo de super resolução (Real-ESRGAN)',
      'inferenceModelNotDownloaded': 'Não baixado',
      'inferenceModelValidating': 'Validando a integridade do modelo',
      'inferenceModelVerified': 'Baixado e com integridade verificada',
      'inferenceModelInvalid': 'Modelo corrompido ou inválido; baixe novamente',
      'inferenceSessionStatus': 'Status da Session',
      'inferenceSessionBackendUnavailable':
          'O runtime de inferência ou o backend selecionado está indisponível',
      'inferenceSessionWaitingForModel':
          'Aguardando um modelo baixado e verificado',
      'inferenceSessionNotTested':
          'Ainda não criada; será verificada na primeira inferência',
      'inferenceSessionReady': 'Criada com sucesso e pronta para inferência',
      'inferenceSessionFailed':
          'A última criação falhou; verifique os logs ou altere o backend',
      'inferenceFrameworkNote':
          'Provedores, integridade do modelo e Session são detectados separadamente.',
      'inferenceBackendAuto': 'Automático',
      'inferenceBackendCpu': 'CPU',
      'inferenceBackendDirectml': 'DirectML (GPU)',
      'inferenceBackendCuda': 'CUDA (GPU NVIDIA)',
      'inferenceBackendOpenvino': 'OpenVINO',
      'inferenceBackendNnapi': 'NNAPI (Android)',
      'inferenceBackendCoreml': 'CoreML (Apple)',
      'inferenceBackendVulkan': 'Vulkan',
      'inferenceBackendXnnpack': 'XNNPACK',
      'imageTranslationOcrEngineOnnx': 'ONNX (no dispositivo)',
      'imageTranslationOcrNotConfigured':
          'O motor OCR ONNX ainda não está configurado. Integre modelos no backend de inferência.',
      'superResolutionEngine': 'Motor',
      'superResolutionEngineNcnnVulkan': 'ncnn-vulkan (externo)',
      'superResolutionEngineOnnx': 'ONNX (no aplicativo)',
      'onnxModelDescRapidOcrSmall':
          'Dicionário multilíngue completo do PP-OCRv6 com alta precisão de reconhecimento em tamanho e velocidade moderados. Bom para a maioria dos quadrinhos e imagens.',
      'onnxModelDescRapidOcrTiny':
          'Dicionário reduzido e redes leves: a camada mais rápida e menor, mas com um conjunto de caracteres menor e precisão ligeiramente menor em glifos complexos. Ideal para dispositivos fracos ou uso focado em velocidade.',
      'onnxModelDescRealEsrgan6B':
          'Camada de alta qualidade: mais detalhes e melhor qualidade, mais lenta.',
      'onnxModelDescRealEsrgan4B32F':
          'Camada rápida: cerca de 3-4x mais rápida com um pouco menos de detalhes; ideal para processamento em lote.',
      'superResolutionModelPickerHint':
          'Trocar de modelo reprocessa páginas ampliadas',
      'stopSuperResolution': 'Stop Super Resolution',
      'deleteSuperResolvedImage': 'Delete Super Resolved Image',
      'superResolveOriginalImageHint':
          'Process original image cost more time, space and performance, are you sure to continue?',
      'verityAppLinks4Android12': 'Verity App Links(Android 12+)',
      'verityAppLinks4Android12Hint':
          'For Android 12+, you need to manually add link to verified links in order to open JHenTai in 3-rd apps',
      'noImageMode': 'No Image Mode',
      'exportData': 'Export Data',
      'exportDataHint': 'Export configs, block rules and history',
      'selectExportItems': 'Select Export Items',
      'importData': 'Import Data',
      'importDataHint':
          'App will shutdown automatically after importing to apply the latest configuration',

      /// host mapping page
      'hostDataSource':
          'Não há necessidade de alterar por padrão.\nFonte de dados: https://dns.google/',

      /// proxy page
      'proxySetting': 'Proxy Setting',
      'proxyType': 'Proxy Type',
      'systemProxy': 'System',
      'httpProxy': 'HTTP',
      'socks5Proxy': 'SOCKS5',
      'socks4Proxy': 'SOCKS4',
      'directProxy': 'DIRECT',
      'address': 'Address',

      /// security setting page
      'enablePasswordAuth': 'Enable Password Auth',
      'enableBiometricAuth': 'Ativar autenticação biométrica',
      'enableAuthOnResume': 'Enable Auth on Resume',
      'enableAuthOnResumeHints': '3 segundos de atraso',
      'enableBlurBackgroundApp':
          'Ative a página de desfoque ao alternar para o plano de fundo',
      'hideImagesInAlbum': 'Hide Images in Album',
      'hideImagesInAlbumHints':
          'If you changed default download path, you need to create .nomedia manually',

      /// read setting page
      'enableImmersiveMode': 'Habilitar modo imersivo',
      'keepScreenAwakeWhenReading': 'Keep Screen Awake When Reading',
      'enableCustomReadBrightness': 'Enable Custom Brightness When Reading',
      'spaceBetweenImages': 'Space Between Images',
      'enableImmersiveHint': 'Esconder barra do sistema',
      'enableImmersiveHint4Windows': 'Hide Title Bar',
      'deviceOrientation': 'Device Orientation',
      'landscape': 'Landscape',
      'portrait': 'Portrait',
      'readDirection': 'Direção da leitura',
      'enableOrientationSpecificReadDirection':
          'Direção de leitura por orientação',
      'enableOrientationSpecificReadDirectionHint':
          'Definir direções de leitura diferentes para orientações retrato e paisagem',
      'portraitReadDirection': 'Direção de leitura (retrato)',
      'landscapeReadDirection': 'Direção de leitura (paisagem)',
      'autoSwitchedReadDirection':
          'Direção de leitura alterada automaticamente',
      'notchOptimization': 'Notch Optimization',
      'notchOptimizationHint':
          'Add padding before the first image to avoid the notch and status bar',
      'imageRegionWidthRatio': 'Image Region Width Ratio',
      'portraitImageRegionWidthRatio': 'Portrait Image Width Ratio',
      'landscapeImageRegionWidthRatio': 'Landscape Image Width Ratio',
      'gestureRegionWidthRatio': 'Gesture Region Width Ratio',
      'useThirdPartyViewer': 'Usar visualizador personaliado',
      'thirdPartyViewerPath':
          'Localização do visualizador personalizado(Arquivo executável)',
      'showThumbnails': 'Mostrar miniaturas',
      'showScrollBar': 'Show Scroll Bar',
      'showStatusInfo': 'Mostrar status na parte inferior',
      'autoModeInterval': 'Intervalo de virada de página',
      'autoModeStyle': 'Estilo do modo automático',
      'scroll': 'Rolagem',
      'turnPage': 'Virar página',
      'top2bottomList': 'Top to Bottom (Continuous)',
      'left2rightSinglePage': 'Left to Right (Single Page)',
      'left2rightSinglePageFitWidth': 'Left to Right (Fit Width)',
      'right2leftSinglePage': 'Right to Left (Single Page)',
      'right2leftSinglePageFitWidth': 'Right to Left (Fit Width)',
      'left2rightDoubleColumn': 'Left to Right (Double Column)',
      'right2leftDoubleColumn': 'Right to Left (Double Column)',
      'left2rightList': 'Left to Right (Continuous)',
      'right2leftList': 'Right to Left (Continuous)',
      'enablePageTurnByVolumeKeys': 'Use volume key to turn page',
      'enablePageTurnByVolumeKeysHint':
          'No iOS, se o volume estiver em 0 ou 100%, ele será ajustado automaticamente ao entrar no leitor para suportar a virada de página e restaurado ao sair',
      'enablePageTurnAnime': 'Ativar animação de virada',
      'enableDoubleTapToScaleUp': 'Ativar toque duplo para aumentar a escala',
      'enableTapDragToScaleUp': 'Enable Tap Drag to Scale up',
      'disableGestureWhenScrolling': 'Disable Gesture When Scrolling',
      'disablePageTurningOnTap': 'Disable Page Turning On Tap',
      'enableBottomMenu': 'Enable Bottom Menu',
      'reverseTurnPageDirection': 'Reverse Page Turning Direction',
      'turnPageMode': 'Modo de virar página',
      'turnPageModeHint': 'Para a próxima tela ou próxima imagem',
      'enableImageMaxKilobytes': 'Enable Image Compression',
      'imageMaxKilobytes': 'Image Max Size',
      'imageMaxKilobytesHint':
          'Images larger than this size will be compressed',
      'image': 'Imagem',
      'screen': 'Tela',
      'preloadDistanceInOnlineMode': 'Preload Distance(Online)',
      'preloadDistanceInLocalMode': 'Preload Distance(Local)',
      'ScreenHeight': 'Screen',
      'preloadPageCount': 'Preload Page Count(Online)',
      'preloadPageCountInLocalMode': 'Preload Page Count(Local)',
      'failedImageRetryScope': "Escopo de repetição de imagens com falha",
      'failedImageRetryScopeHint':
          "Escopo ao tocar em uma imagem online com falha para recarregá-la",
      'imageTimeoutRetry': 'Repetir por tempo esgotado',
      'imageTimeoutRetryHint':
          'Tentar novamente quando uma imagem online não responder ou o progresso travar',
      'imageTimeoutRetryCount': 'Número de tentativas',
      'imageTimeoutRetryInterval': 'Limite de tempo',
      'retrySingleImage': "Apenas a imagem tocada",
      'retryCurrentPageAndAfter': "Imagem atual e seguintes",
      'retryAllFailedImages': "Todas as imagens com falha",
      'continuousScroll': 'Rolagem contínua',
      'continuousScrollHint': 'Junte várias imagens',
      'doubleColumn': 'Duas Colunas',
      'displayFirstPageAlone': 'Display First Page Alone',
      'displayFirstPageAloneGlobally': 'Display First Page Alone(Globally)',
      'portraitDisplayFirstPageAlone': 'Portrait Display First Page Alone',
      'landscapeDisplayFirstPageAlone': 'Landscape Display First Page Alone',
      'toggleFullScreen': 'Toggle Full Screen',
      'keyboardShortcuts': 'Atalhos de Teclado',
      'keyboardShortcutsHint':
          'Personalizar atalhos de teclado da página de leitura',
      'pressAnyKey': 'Pressione qualquer tecla...',
      'unboundKey': 'Sem vínculo',
      'clearKey': 'Limpar',
      'resetAll': 'Redefinir tudo',
      'resetSuccess': 'Redefinido para padrão',
      'keyConflict': 'Conflito de tecla',
      'fixedKeyHint': 'Tecla fixa, não personalizável',
      'pressAnyKeyOrMouseSideButton':
          'Pressione qualquer tecla ou botão lateral do mouse...',
      'mouseButton4Name': 'Mouse Avançar',
      'mouseButton5Name': 'Mouse Voltar',
      'toLeft': 'Virar à esquerda',
      'toRight': 'Virar à direita',
      'enableAutoScaleUp':
          'Ativar dimensionamento automático de imagens grandes',
      'enableAutoScaleUpHints':
          'Tornar a largura da imagem igual à largura da tela',

      /// preference setting page
      'showR18GImageDirectly': 'Show R18G Image Directly',
      'defaultTab': 'Default Tab',
      'defaultDownloadTab': 'Default Download Tab',
      'showUtcTime': 'Show UTC Time for Gallery',
      'showDawnInfo': 'Show new dawn event',
      'showEncounterMonster': 'Show hentaiVerse monster encounter event',

      /// log page
      'logList': 'Lista de resgistro(log)',

      /// super resolution setting page
      'downloadSuperResolutionModelHint': 'Download Model From Github',
      'modelDirectoryPath': 'Model Directory Path',
      'upSamplingScale': 'Up Sampling Scale',
      'modelType': 'Choose Model',
      'x4plusHint': 'Take up more space but faster at most time',
      'x4plusAnimeHint': 'Take up less space but slower at most time',
      'enable4OnlineReading': 'Process Automatically While Reading Online',

      /// download page
      'local': 'Local',
      'reDownload': 'Baixar novamente',
      'delete': 'Apagar',
      'deleteTask': 'Apagar apenas tarefa',
      'deleteTaskAndImages': 'Apagar tarefa e imagens',
      'unlocking': 'desbloqueio',
      'unlocked': 'Unlocked',
      'parsingDownloadPageUrl': 'Analisando Ⅰ',
      'parsedDownloadPageUrl': 'Analisando Ⅰ',
      'parsingDownloadUrl': 'Analisando Ⅱ',
      'parsedDownloadUrl': 'Analisando Ⅱ',
      'waitingIsolate': 'Waiting',
      'downloaded': 'Baixado',
      'downloadFailed': 'Download falhou',
      'unpacking': 'Desenpacotando',
      'completed': 'Completo',
      'needReUnlock': 'Precisa de novo desbloqueio',
      'reUnlock': 'Desbloquear novamente',
      'reUnlockHint':
          'Atenção! precisa comprar este arquivo novamente para desbloque-lo novamente.',
      'downloadHelpInfo':
          'Se você não conseguir fazer o download e encontrar erros como a tabela não existe nos logs, desinstale o aplicativo atual e reinstale.',
      'localGalleryHelpInfo':
          'Load gallerys which is not downloaded by JHenTai. Add config in Download Setting -> Extra Gallery Scan Path and then refresh.',
      'localGalleryHelpInfo4iOSAndMacOS':
          'Load gallerys which is not downloaded by JHenTai. Put your gallerys in default download path and then refresh',
      'deleteLocalGalleryHint': 'Delete your local files',
      'priority': 'Prioridade',
      'highest': 'Alta',
      'default': 'Padrão',
      'newGalleryCount': 'Nova contagem de galerias',
      'changePriority': 'Mudar prioridade',
      'changeGroup': 'Mudar grupo',
      'chooseGroup': 'Escolhar grupo',
      'renameGroup': 'Renomear grupo',
      'deleteGroup': 'Apagar grupo',
      'existingGroup': 'Existing Group',
      'groupName': 'Nome do grupo',
      'drag2sort': 'Drag to Sort',
      'switch2GridMode': 'Switch to Grid Mode',
      'switch2ListMode': 'Switch to List Mode',
      'multiSelect': 'Multi-Select',
      'multiSelectHint': 'Tap to select',
      'resumeAllTasks': 'Resume All Tasks',
      'pauseAllTasks': 'Pause All Tasks',
      'requireDownloadComplete': 'Require download complete',
      'operationHasCompleted': 'The operation has completed',
      'operationInProgress': 'The operation is in progress',
      'startProcess': 'Start Process',
      'multiReDownloadHint': 'You will re-download all selected gallerys.',
      'multiChangeGroupHint': 'You will change group of all selected gallerys.',
      'multiDeleteHint': 'You will delete all selected gallerys.',
      'blankImageHint':
          'Downloading the image returned an empty result, trying to re-parse.',
      'peakHoursHint':
          'Downloading original files during peak hours requires GP, and you do not have enough, downloading is paused.',
      'oldGalleryHint':
          'Downloading original files of this gallery requires GP, and you do not have enough.',
      'exceedLimitHint':
          'You have reached the image limit, and do not have sufficient GP to buy a download quota.',
      'deleteUpdatingDependentHint':
          'Another gallery\'s update relies on current gallery, you\'d better delete after update has completed.',
      'migrateToDownload': 'Migrate To 「Download」',
      'refresh': 'Refresh',

      /// download search page
      'simpleSearch': 'Simple',
      'regexSearch': 'Regex',

      /// search dialog
      'searchConfig': 'Opções de pesquisa',
      'addTabBar': 'Adicionar barra de guias',
      'updateTabBar': 'Atualizar barra de guias',
      'addQuickSearch': 'Adicionar',
      'updateQuickSearch': 'Atualizar',
      'filter': 'Filtro',
      'tabBarName': 'Nome da TabBar',
      'quickSearchName': 'Nome',
      'pleaseInputValidName': 'Por favor insira um nome válido',
      'sameNameExists': 'O mesmo nome já existe',
      'sameConfigExists': 'Same config exists',
      'searchType': 'Tipo de pesquisa',
      'popular': 'Popular',
      'ranklist': 'Lista de classificação',
      'ranklistBoard': 'lista de classificação (placa)',
      'watched': 'Assistido',
      'history': 'História',
      'keyword': 'Palavra-chave',
      'orderBy': 'Order by',
      'favoritedTime': 'Favorited Time',
      'publishedTime': 'Published Time',
      'backspace2DeleteTag': 'Backspace para excluir tag',
      'searchGalleryName': 'Pesquisar nome da galeria',
      'searchGalleryTags': 'Pesquisar tags da galeria',
      'searchGalleryDescription': 'Pesquisar descrição da galeria',
      'onlySearchExpungedGalleries': 'Pesquisar galerias eliminadas',
      'onlyShowGalleriesWithTorrents': 'Mostrar apenas galerias com torrents',
      'searchLowPowerTags': 'Pesquisar tags de baixo consumo',
      'searchDownVotedTags': 'Pesquisar tags pouco votadas',
      'pageAtLeast': 'Página no mínimo',
      'pageAtMost': 'Página no máximo',
      'pagesBetween': 'Páginas entre',
      'pageRangeSelectHint':
          'min <= 1000, max >= 10\nmin/max <= 0.8, max-min >= 20',
      'to': 'para',
      'minimumRating': 'Classificação mínima',
      'disableFilterForLanguage': 'Desativar filtro para idioma',
      'disableFilterForUploader': 'Desativar filtro para uploader',
      'disableFilterForTags': 'Desativar filtro para Tags',
      'searchName': 'Nome de pesquisa',
      'searchTags': 'Tags de pesquisa',
      'searchNote': 'Nota de pesquisa',
      'allTime': 'Tudo',
      'year': 'Ano',
      'month': 'Mês',
      'day': 'Dia',
      'favoriteHint': 'Qualifiers: tag/title/comment/favnote',

      /// popular page
      'getPopularListFailed': 'Falha ao obter lista de popularidade',

      /// ranklist page
      'getRanklistFailed': 'Falha ao obter lista de classificação',
      'getSomeOfGallerysFailed': 'Falha ao obter algumas das galerias',

      /// history page
      'getHistoryGallerysFailed':
          'Falha ao obter alguns dos histórico galerias',

      /// search page
      'search': 'Pesquisar',
      'searchFailed': 'Falha ao pesquisar',
      'fileSearchFailed': 'Falha ao pesquisr arquivo',
      'tab': 'Tab',
      'openGallery': 'Open Gallery',
      'tapChip2Delete': 'Tap chip to delete\nLong press button to delete all',
      'accurateCountTemplate': '%s results',
      'hundredsOfCountTemplate': 'Hundreds of results',
      'thousandsOfCountTemplate': 'Thousands of results',

      /// about page
      'author': 'Autor',
      'Q&A': 'Q&A',
      'telegramHint': 'You can ask your questions in github first',

      /// download setting page
      'downloadPath': 'Caminho de download',
      'changeDownloadPathHint':
          'Pressione e segure para mudar. Alterar o caminho de download copiará as galerias baixadas automaticamente e manterá os arquivos antigos. Se você achar que não consegue carregar a imagem, tente redefinir o caminho.',
      'resetDownloadPath': 'Redefinir caminho de download',
      'singleImageSavePath': 'Single Image Save Path',
      'extraGalleryScanPath': 'Extra Gallery Scan Path',
      'extraGalleryScanPathHint': 'To scan and load local gallerys',
      'downloadOriginalImage': 'Imagem original',
      'downloadOriginalImageByDefault': 'Escolher imagem original por padrão',
      'originalImage': 'Original',
      'resampleImage': 'Redimensionada',
      'defaultGalleryGroup': 'Default Gallery Group',
      'prioritizeRecentGalleryGroups':
          'Priorizar grupos de galeria usados recentemente',
      'defaultArchiveGroup': 'Default Archive Group',
      'never': 'Nunca',
      'manual': 'Manual',
      'always': 'Sempre',
      'longPress2Reset': 'Pressione e segure para redefinir',
      'needPermissionToChangeDownloadPath':
          'Precisa de permissão para alterar o caminho de download',
      'invalidPath':
          'Caminho inválido. Evite usar o caminho do sistema, caminho raiz ou caminho do cartão SD.',
      'downloadTaskConcurrency': 'Download simultâneo',
      'needRestart': 'Precisa reiniciar',
      'speedLimit': 'Limite de velocidade',
      'speedLimitHint': 'Não baixar muito rápido',
      'per': 'por',
      'images': 'imagens',
      'downloadTimeout': 'Tempo limite de download',
      'downloadAllGallerysOfSamePriority':
          'Download All Gallerys of Same Priority',
      'downloadAllGallerysOfSamePriorityHint':
          'Download only 1 gallery simultaneously in 1 group with highest priority by default',
      'alwaysUseDefaultGroup': 'Sempre usar o grupo padrão',
      'enableStoreMetadataForRestore':
          'Ativar metadados da loja para restauração',
      'enableStoreMetadataForRestoreHint':
          'Se desabilitar isso, você não poderá restaurar as tarefas de download',
      'archiveDownloadIsolateCount': 'Archive Download Thread Count',
      'archiveDownloadIsolateCountHint':
          'Sum of threads for all tasks needs to be less than 10, otherwise the download will fail',
      'manageArchiveDownloadConcurrency': 'Manage Archive Download Concurrency',
      'manageArchiveDownloadConcurrencyHint':
          'Archive will wait until there are enough threads to download',
      'deleteArchiveFileAfterDownload':
          'Delete Archive .zip File After Download',
      'restoreDownloadTasks': 'Restaurar tarefas de download',
      'restoreDownloadTasksHint': 'Restaurar tarefas de download por metadados',
      'restoreDownloadTasksSuccess':
          'Tarefas de download restauradas com sucesso',
      'restoredCount': 'Contagem de tarefas restaurada',
      'restoredGalleryCount': 'Contagem de galerias restaurada',
      'restoredArchiveCount': 'Contagem de arquivos restaurada',
      'restoreTasksAutomatically': 'Restore Tasks Automatically',
      'restoreTasksAutomaticallyHint':
          'Restore tasks automatically when app launched',
      'brokenDownloadPathHint':
          'Parece que seu caminho de download está quebrado, a função de download pode ser ineficaz',
      'brokenExtraScanPathHint':
          'Seems your default local gallery path is broken, local gallery may be not recognized',
      'useJH2UpdateGallery': 'Use JH server to accelerate gallery updates',

      /// archive bot settings
      'archiveBotSettings': 'Archive Bot Settings',
      'archiveBotSettingsHint': 'Use archive bot to get archive links for free',
      'apiSetting': 'API Setting',
      'archiveBotProtocol': 'Protocol',
      'apiAddress': 'Address',
      'apiKey': 'Key',
      'apiKeyHint': 'Enter the key you got from Telegram bot',
      'dailyCheckin': 'Daily Check-in',
      'currentBalance': 'Current GP Balance',
      'checkBalanceFailed': 'Failed to get GP balance',
      'checkInFailed': 'Check-in failed',
      'checkInSuccess': 'Check-in success',
      'checkInSuccessHint': 'Got GP: %s, current total GP: %s.',
      'pauseDownloadByInvalidArchiveBotKey':
          'Archive bot settings is invalid, download paused',
      'chooseArchiveParseSource': 'Change Parse Source',
      'official': 'Official',
      'archiveBot': 'Archive Bot',
      'changeParseSource2Official': 'Change parse source to official',
      'changeParseSource2Bot': 'Change parse source to archive bot',
      'invalidParam': 'Invalid parameter',
      'invalidApiKey': 'Invalid API key',
      'banned': 'You have been banned',
      'fetchGalleryInfoFailed': 'Failed to get gallery info',
      'insufficientGP': 'Insufficient GP',
      'parseFailed': 'Parse failed',
      'checkedIn': 'Already checked in today',
      'serverError': 'Archive bot internal error',
      'useProxyServer': 'Use JHenTai Proxy Server',
      'useProxyServerHint': 'Route requests through JHenTai server',

      /// password setting dialog
      'setPasswordHint': 'Please input your password',
      'confirmPasswordHint': 'Please input your password again',
      'passwordNotMatchHint': 'Password not match, try again',

      /// cloud setting page
      'serverCondition': 'Server Condition',
      'configSync': 'Config Sync',
      'configSyncHint': 'Store your config data in cloud(up to 50 entries)',
      'upload2cloud': 'Upload to Cloud',
      'upload2cloudHint': 'Upload your current local configuration',
      'tap2upload': 'Tap to upload',
      'copyIdentificationCodeSuccess':
          'Upload successfully. Identification code has been copied',
      'copyShareCode': 'Copy Share Code',
      'import': 'Import',
      'save2Local': 'Save to Local',
      'readIndexRecord': 'Read Progress',
      'quickSearch': 'Quick Search Config',
      'blockRules': 'Block Rules',
      'searchHistory': 'Search History',
      'galleryHistory': 'Gallery History',

      /// block rule page
      'configureBlockRuleFailed': 'Configure block rule failed',
      'removeBlockRuleFailed': 'Remove block rule failed',
      'inputNumberHint': 'Please input a correct number',
      'inputRegexHint': 'Please input a correct regex',
      'useBuiltInBlockedUsers': 'Enable Built-in User Blocklist',
      'useBuiltInBlockedUsersHint':
          'Filter out gallery comments from users on the blocklist',
      'blockingRules': 'Block Rules',
      'blockingRulesHint':
          'Additional blocking rules for gallerys and comments',
      'blockingTarget': 'Blocking Target',
      'blockingAttribute': 'Blocking Attribute',
      'blockingPattern': 'Blocking Pattern',
      'blockingExpression': 'Blocking Expression',
      'contain': 'Contain',
      'notContain': 'Not Contain',
      'regex': 'Regex',
      'comment': 'Comment',
      'tag': 'Tag',
      'userId': 'UserId',
      'content': 'Content',
      'incompleteInformation': 'Incomplete information',
      'noBlockingRuleHint': 'Add at least 1 rule',
      'notSameBlockingRuleTargetHint':
          'All sub-rules should have the same blocking target',
      'blockingRuleHelp': '''
Blocking Target: Filter galleries on the list page or filter comments on the details page. All sub-rules under the same rule must have the same blocking target.
Blocking Attribute: Specify the attribute of the target based on which the rule is written to block.
Blocking Pattern: Use regular expressions for complex scenarios.
Blocking Expression: Simple strings or regular expressions.

Note1: Different rules have an OR (||) relationship, while all sub-rules under the same rule have an AND (&&) relationship.
Note2: When blocking tag, the rule will check each tag in the gallery, the expression should be written for a single tag.
Note3: When blocking tag, you need specify full tag with namespace if you use '=' rule.
Note4: You need to use a gallery layout that can display all tags in E-Hentai, such as "Extended," otherwise some galleries may not be filtered correctly.

Example 1: Block galleries that have the "yaoi" tag and do not have the "tomgirl" tag————Gallery Tag Contain male:yaoi && Gallery Tag NotContain male:tomgirl
Example 2: Block comments with a score not exceeding 10————Comment Score <= 10
    ''',

      /// quick search page
      'quickSearch': 'Pesquisa rápida',

      /// dashboard page
      'seeAll': 'Tudo',
      'newest': 'Mias novo',

      /// torrent dialog
      'outdated': 'Outdated',

      /// tag dialog
      'warningImageHint': 'R18G image, Tap to view',

      /// tagSet dialog
      'chooseTagSet': 'Choose Tag Set',

      /// tag namespace
      'language': 'Idioma',
      'artist': 'Artista',
      'character': 'Personagem',
      'female': 'Feminino',
      'male': 'Masculino',
      'parody': 'Paródia',
      'group': 'Grupo',
      'mixed': 'Misturado',
      'Coser': 'Cosplayer',
      'cosplayer': 'Cosplayer',
      'reclass': 'Reclassificar',
      'temp': 'Temporário',
      'other': 'Outro',

      /// image text translation
      'imageTextTranslation': 'Tradução de texto da imagem',
      'translateImageText': 'Reconhecer e traduzir esta página',
      'recognizingImageText': 'Reconhecendo texto da imagem…',
      'translatingImageText': 'Traduzindo texto da imagem…',
      'showTranslation': 'Mostrar tradução',
      'showOriginal': 'Mostrar original',
      'copy': 'Copiar',
      'retry': 'Tentar novamente',
      'configure': 'Configurar',
      'saveSetting': 'Salvar',
      'imageTranslationNoResult': 'Nenhum resultado para exibir',
      'imageTranslationConfigureHint':
          'O texto original foi reconhecido. Primeiro configure um provedor de tradução nas configurações avançadas.',
      'imageTranslationUnsupportedPlatform':
          'OCR de imagem ainda não está disponível nesta plataforma.',
      'imageTranslationOcrUnavailable':
          'Executável OCR não encontrado. Instale ou configure o Tesseract no desktop.',
      'imageTranslationOcrFailed':
          'O reconhecimento de texto falhou. Verifique os pacotes de idioma do OCR e o formato da imagem.',
      'imageTranslationNoText': 'Nenhum texto foi reconhecido nesta imagem.',
      'imageTranslationAlreadyTranslated': 'Esta página já foi traduzida.',
      'imageTranslationCancelled': 'Tradução cancelada.',
      'imageTranslationRequestFailed':
          'A solicitação de tradução falhou. Verifique o endpoint, a chave e a rede.',
      'imageTranslationInvalidResponse':
          'O provedor de tradução retornou um resultado inválido.',
      'imageTranslationFailed': 'A tradução de texto da imagem falhou.',
      'imageTranslationPaddleNotReady':
          'O ambiente de execução do PaddleOCR não está instalado. Instale-o nas configurações avançadas primeiro.',
      'imageTranslationDeletePaddleRuntime':
          'Excluir ambiente de execução do PaddleOCR',
      'imageTranslationDeletePaddleHint':
          'Remove o ambiente virtual e os modelos baixados.',
      'imageTranslationDeletePaddleConfirm':
          'Excluir o ambiente de execução do PaddleOCR?',
      'imageTranslationEnableThinking': 'Usar raciocínio',
      'imageTranslationEnableThinkingHint':
          'Desativado traduz mais rápido; ativado raciocina mais profundamente.',
      'imageTranslationTranslateScope': 'Escopo da tradução',
      'imageTranslationScopeCurrent': 'Apenas a página atual',
      'imageTranslationScopeSubsequent': 'Página atual e seguintes',
      'imageTranslationContextPages': 'Páginas por solicitação de contexto',
      'imageTranslationContextPagesValue': '@count página(s)',
      'imageTranslationContextAppleUnsupported':
          'A Tradução da Apple atualmente aceita uma página por solicitação.',
      'imageTranslationCachedRetranslate': 'Em cache · Retraduzir',
      'translationProgress': 'Traduzindo @current/@total · @stage',
      'translationStageIdle': 'Preparando',
      'translationStageRecognizing': 'Reconhecendo',
      'translationStageTranslating': 'Traduzindo',
      'translationStageMasking': 'Mascarando',
      'translationStageEmbedding': 'Inserindo texto',
      'translationStageDone': 'Concluído',
      'imageTranslationSourceUnavailable':
          'A imagem atual não está disponível.',
      'imageTranslationSettingHint': 'Configurar OCR e provedor de tradução',
      'imageTranslationOcrSection': 'Reconhecimento de texto',
      'imageTranslationOcrHint':
          'No desktop, o Tesseract local é usado por padrão. Instale os pacotes de idioma necessários.',
      'imageTranslationOcrExecutable': 'Executável OCR',
      'imageTranslationOcrLanguage': 'Idiomas OCR',
      'imageTranslationTranslatorSection': 'Provedor de tradução',
      'imageTranslationTranslatorEngine': 'Mecanismo de tradução',
      'imageTranslationTranslatorEngineApi': 'API de terceiros',
      'imageTranslationTranslatorEngineApple': 'Apple no dispositivo',
      'imageTranslationTranslatorEngineLocal': 'GGUF local',
      'imageTranslationLocalGgufHint':
          'Usa o modelo GGUF baixado e o runtime local llama.cpp configurado.',
      'imageTranslationTranslatorHint':
          'Usa um endpoint OpenAI-compatible Chat Completions. A chave fica somente neste dispositivo.',
      'imageTranslationEndpoint': 'Endpoint',
      'imageTranslationModel': 'Modelo',
      'imageTranslationTargetLanguage': 'Idioma de destino',
      'imageTranslationApiTestHint':
          'Informe a URL base e a chave da API e teste para carregar os modelos disponíveis.',
      'imageTranslationProvider': 'Formato da API',
      'imageTranslationOpenAICompatible': 'Compatível com OpenAI',
      'imageTranslationApiBaseUrl': 'URL base da API',
      'imageTranslationTestAndFetchModels': 'Testar e buscar modelos',
      'imageTranslationFetchModelsFirst':
          'Teste a API e busque os modelos primeiro',
      'imageTranslationApiTestSuccess':
          'Conexão bem-sucedida; @count modelos encontrados',
      'imageTranslationApiTestFailed': 'Falha no teste da API: @error',
      'imageTranslationOcrDownloadHint':
          'Baixe modelos de idioma tessdata_fast para o diretório de dados do Tesseract.',
      'imageTranslationOcrDataDirectory': 'Diretório de dados OCR',
      'imageTranslationChooseDirectory': 'Escolher diretório de dados',
      'imageTranslationDetectOcr': 'Detectar OCR local',
      'imageTranslationOcrModelSource': 'Fonte do modelo OCR',
      'imageTranslationGiteeMirror': 'Espelho comunitário Gitee (China)',
      'imageTranslationGithubOfficial': 'Fonte oficial do GitHub',
      'imageTranslationOcrInstalled': 'Instalado',
      'imageTranslationOcrNotInstalled': 'Não instalado',
      'imageTranslationOcrDetectFailed':
          'Falha ao detectar OCR. Verifique o caminho do executável.',
      'imageTranslationOcrDirectoryRequired':
          'Escolha ou detecte o diretório de dados OCR primeiro.',
      'imageTranslationOcrDownloadSuccess': 'Modelo OCR baixado.',
      'imageTranslationOcrDownloadFailed':
          'Falha ao baixar o modelo OCR. Tente outra fonte.',
      'imageTranslationOcrEngineAppleLiveText': 'Apple Live Text',
      'imageTranslationAppleLiveTextLanguage':
          'Idioma de reconhecimento do Apple Live Text',
      'imageTranslationAppleLiveTextHint':
          'OCR no dispositivo via Apple Vision. Disponível em iOS e macOS, sem download de modelo.',
      'imageTranslationAppleLiveTextUnavailable':
          'O Apple Live Text está disponível apenas em iOS e macOS.',
      'imageTranslationMethodSection': 'Método de tradução',
      'imageTranslationMethodAppleLiveText': 'Apple Live Text',
      'imageTranslationMethodCustom': 'Personalizado',
      'imageTranslationAppleLiveTextUseApi':
          'Usar API de terceiros para tradução',
      'imageTranslationAppleLiveTextUseApiHint':
          'Reutiliza a mesma API compatível com OpenAI / Anthropic do modo personalizado em vez da tradução no dispositivo da Apple.',
      'imageTranslationAppleLiveTextOnDeviceHint':
          'A tradução é feita no dispositivo pela Apple, independentemente do OCR. Exige iOS 26 / macOS 26 ou superior.',
      'autoTranslateGalleryText':
          'Traduzir títulos e comentários automaticamente',
      'autoTranslateGalleryTextHint':
          'Quando ativado, títulos e comentários de galerias visíveis são traduzidos no dispositivo (requer tradução on-device da Apple).',
      'imageTranslationTranslationUnavailable':
          'A tradução no dispositivo da Apple exige iOS 26 / macOS 26 ou superior. Selecione a API de terceiros neste sistema.',
      'imageTranslationTranslationFailed':
          'Falha na tradução no dispositivo da Apple.',
      'imageTranslationShow': 'Mostrar tradução',
      'imageTranslationHide': 'Ocultar tradução',
      'imageTranslationRetranslate': 'Retraduzir',
      'imageTranslationStart': 'Iniciar tradução',
      'imageTranslationSettings': 'Configurações de tradução',
      'imageTranslationTranslationNotInstalled':
          'Os pacotes de idiomas da tradução no dispositivo da Apple não estão instalados. Instale-os em Ajustes do Sistema → Geral → Idioma e Região → Idiomas de Tradução, ou ative "Usar API de terceiros para tradução".',
      'imageTranslationTranslationNotInstalledIos':
          'Os pacotes de idiomas da tradução no dispositivo da Apple não estão instalados. Instale-os em Ajustes → Traduzir → Idiomas Baixados, ou ative "Usar API de terceiros para tradução".',
    };
  }
}
