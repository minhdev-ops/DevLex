import 'models/term.dart';

/// Một lộ trình nghề nghiệp, chọn thuật ngữ từ chính kho dữ liệu đóng gói.
///
/// Trước đây lộ trình chỉ gồm vài chục mục được gắn tay trường `career`, nên
/// mở ra gần như trống. Mỗi track ở đây chọn theo nhóm chủ đề (tag) và từ khóa
/// trong chính tên/định nghĩa thuật ngữ, rồi cắt còn một danh sách đủ gọn để
/// vẽ sơ đồ tư duy thay vì nhồi hàng nghìn nút.
class CareerTrack {
  const CareerTrack({
    required this.key,
    required this.label,
    required this.group,
    this.tags = const [],
    this.keywords = const [],
    this.limit = 40,
    this.stages = const [],
  });

  final String key;
  final String label;

  /// Nhóm hiển thị trong bộ chọn (Sản phẩm, Hạ tầng, An ninh...).
  final String group;

  /// Thẻ chủ đề khớp là đủ điều kiện (khớp bất kỳ).
  final List<String> tags;

  /// Từ khóa (chữ thường) dò trong viết tắt, tên tiếng Anh và định nghĩa.
  final List<String> keywords;

  /// Số nút tối đa — giữ sơ đồ còn đọc được trên điện thoại.
  final int limit;

  /// Thứ tự học theo từng chặng (mỗi chặng là danh sách viết tắt có trong kho).
  /// Nút ở chặng sau nhận các nút chặng trước làm tiên quyết, nhờ đó sơ đồ có
  /// cạnh thật và có mũi tên thay vì chỉ là lưới ô rời.
  final List<List<String>> stages;

  /// Điểm khớp: khớp ở viết tắt đáng tin hơn khớp trong định nghĩa.
  ///
  /// Từ khóa một chữ phải khớp trọn từ — nếu dò chuỗi con thì "orm" khớp cả
  /// "transf-orm-ation" và "ip" khớp "ZIP", kéo thuật ngữ lạc vào lộ trình.
  int score(Term t) {
    final acronym = t.acronym.toLowerCase();
    final name = t.fullNameEn.toLowerCase();
    final definition = t.shortDefinition.toLowerCase();
    var score = 0;
    for (final k in keywords) {
      if (acronym == k) {
        score += 5;
      } else if (_containsWord(acronym, k)) {
        score += 3;
      } else if (_containsWord(name, k)) {
        score += 2;
      } else if (_containsWord(definition, k)) {
        score += 1;
      }
    }
    if (t.categoryTags.any(tags.contains)) score += 2;
    return score;
  }

  static bool _containsWord(String haystack, String needle) {
    if (needle.contains(' ')) return haystack.contains(needle);
    return RegExp(
      '(^|[^a-z0-9])${RegExp.escape(needle)}(\$|[^a-z0-9])',
    ).hasMatch(haystack);
  }
}

/// Thứ tự ưu tiên khi hai thuật ngữ cùng điểm: dễ trước, rồi theo tên.
int compareCareerTerms(Term a, Term b, CareerTrack track) {
  final sa = track.score(a);
  final sb = track.score(b);
  if (sa != sb) return sb.compareTo(sa);
  final da = _difficultyRank(a.difficulty);
  final db = _difficultyRank(b.difficulty);
  if (da != db) return da.compareTo(db);
  return a.acronym.toLowerCase().compareTo(b.acronym.toLowerCase());
}

int _difficultyRank(String value) => switch (value.toLowerCase()) {
  'beginner' => 0,
  'advanced' => 2,
  _ => 1,
};

/// Các lộ trình nghề nghiệp, nhóm theo mảng để bộ chọn không bị dài.
const careerTracks = <CareerTrack>[
  CareerTrack(
    key: 'frontend',
    label: 'Frontend Developer',
    group: 'Sản phẩm',
    tags: ['Frontend', 'Web'],
    keywords: [
      'css',
      'html',
      'javascript',
      'dom',
      'browser',
      'accessibility',
      'aria',
      'render',
      'spa',
      'ssr',
      'responsive',
      'web',
    ],
    stages: [
      ['Computer programming', 'browser', 'Browsing context'],
      ['Attribute', 'Block-level content', 'Box fragment', 'Bounding box'],
      ['Accessibility', 'ARIA', 'Accessible name', 'Accessibility tree'],
      ['Cache', 'Cookie', 'CORS', 'bfcache'],
      ['Ajax', 'Code splitting', 'Bun', 'BigInt'],
      ['CLS', 'Composite operation', 'Crawler'],
    ],
  ),
  CareerTrack(
    key: 'backend',
    label: 'Backend Developer',
    group: 'Sản phẩm',
    tags: ['Backend', 'Web API', 'API'],
    keywords: [
      'api',
      'rest',
      'graphql',
      'sql',
      'crud',
      'middleware',
      'orm',
      'oauth',
      'jwt',
      'message queue',
      'web service',
    ],
    stages: [
      ['API', 'Web Service'],
      ['REST', 'CRUD', 'HTTP'],
      ['Middleware', 'ORM', 'SQL'],
      ['NoSQL', 'Replication', 'Message Queue'],
      ['API Gateway', 'OAuth', 'JWT'],
      ['GraphQL', 'SQL injection'],
    ],
  ),
  CareerTrack(
    key: 'mobile',
    label: 'Mobile Developer',
    group: 'Sản phẩm',
    tags: ['Frontend'],
    keywords: [
      'mobile',
      'android',
      'ios',
      'app store',
      'smartphone',
      'handset',
      'cellular',
      'tablet',
    ],
    limit: 30,
  ),
  CareerTrack(
    key: 'devops',
    label: 'DevOps Engineer',
    group: 'Hạ tầng',
    tags: ['DevOps', 'methodology', 'Process'],
    keywords: [
      'deploy',
      'container',
      'docker',
      'kubernetes',
      'rollback',
      'staging',
      'hotfix',
      'gitops',
      'ci/cd',
      'pipeline',
      'release',
    ],
    stages: [
      ['Virtualization', 'Virtual Machine'],
      ['Containerization', 'Container', 'Container runtime'],
      ['Docker', 'Container Orchestration', 'Kubernetes'],
      ['Ingress', 'Load Balancer', 'Service Mesh'],
      ['CI/CD', 'CD', 'GitOps'],
      ['Staging', 'Release', 'Rollback', 'Hotfix'],
    ],
  ),
  CareerTrack(
    key: 'cloud',
    label: 'Cloud Native Engineer',
    group: 'Hạ tầng',
    tags: ['cloud-native', 'infrastructure', 'fundamental', 'Cloud Native'],
    keywords: [
      'cloud',
      'orchestration',
      'autoscal',
      'serverless',
      'iaas',
      'paas',
      'faas',
      'virtual',
      'cluster',
      'container',
    ],
    stages: [
      ['Cloud computing', 'Cloud Provider', 'Cloud Consumer'],
      ['IaaS', 'PaaS', 'FaaS'],
      ['Cloud Native Technology', 'Cluster', 'Container Orchestration'],
      ['Autoscaling', 'Immutable Infrastructure'],
      ['Cloud Native Storage', 'Cloud Native Security'],
    ],
  ),
  CareerTrack(
    key: 'network',
    label: 'Network Engineer',
    group: 'Hạ tầng',
    tags: ['networking', 'IETF', 'Network'],
    keywords: [
      'tcp',
      'ip',
      'dns',
      'routing',
      'protocol',
      'tls',
      'http',
      'packet',
      'gateway',
      'proxy',
      'transport',
    ],
    stages: [
      ['Internet Protocol (IP) addresses', 'domain name', 'DNS'],
      ['HTTP', 'HTTP/2', 'HTTP/3', 'https'],
      ['Application Layer', 'gateway', 'API Gateway'],
      ['IPsec', 'Internet Protocol Security', 'Handshake Protocol'],
    ],
  ),
  CareerTrack(
    key: 'security',
    label: 'Security Engineer',
    group: 'An ninh',
    tags: ['Security', 'security'],
    keywords: [
      'security',
      'attack',
      'threat',
      'vulnerab',
      'authentic',
      'authoriz',
      'encrypt',
      'firewall',
      'intrusion',
      'malware',
    ],
    limit: 50,
  ),
  CareerTrack(
    key: 'crypto',
    label: 'Cryptography',
    group: 'An ninh',
    keywords: [
      'cryptograph',
      'cipher',
      'hash',
      'key exchange',
      'certificate',
      'pki',
      'signature',
      'nonce',
      'entropy',
      'public key',
    ],
    limit: 30,
  ),
  CareerTrack(
    key: 'data',
    label: 'Data Engineer',
    group: 'Dữ liệu & AI',
    tags: ['Database'],
    keywords: [
      'database',
      'sql',
      'storage',
      'replication',
      'warehouse',
      'analytics',
      'schema',
      'big data',
      'data model',
    ],
    limit: 30,
  ),
  CareerTrack(
    key: 'ai_ml',
    label: 'AI / Machine Learning',
    group: 'Dữ liệu & AI',
    keywords: [
      'machine learning',
      'neural',
      'inference',
      'training',
      'artificial intelligence',
      'classifier',
      'deep learning',
    ],
    limit: 25,
  ),
  CareerTrack(
    key: 'architecture',
    label: 'Software Architect',
    group: 'Kiến trúc',
    tags: ['architecture', 'fundamental', 'Architecture'],
    keywords: [
      'architecture',
      'distributed',
      'scalab',
      'microservice',
      'monolith',
      'design pattern',
      'coupling',
      'reliab',
    ],
    limit: 35,
  ),
  CareerTrack(
    key: 'qa',
    label: 'QA / Test Engineer',
    group: 'Chất lượng',
    tags: ['Quality'],
    keywords: [
      'test',
      'quality',
      'verification',
      'validation',
      'assurance',
      'review',
      'conformance',
    ],
    limit: 30,
  ),
  CareerTrack(
    key: 'product',
    label: 'Product & Process',
    group: 'Chất lượng',
    tags: ['Process', 'Communication', 'Collaboration'],
    keywords: [
      'agile',
      'scrum',
      'sprint',
      'requirement',
      'stakeholder',
      'process',
      'documentation',
      'collaboration',
    ],
    limit: 25,
  ),
  CareerTrack(
    key: 'soc',
    label: 'SOC Analyst',
    group: 'An ninh',
    tags: ['Security'],
    keywords: [
      'monitoring',
      'incident',
      'alert',
      'log',
      'detection',
      'soc',
      'security operations',
    ],
    limit: 30,
  ),
  CareerTrack(
    key: 'pentest',
    label: 'Penetration Tester',
    group: 'An ninh',
    keywords: [
      'penetration',
      'attack',
      'exploit',
      'vulnerab',
      'red team',
      'intrusion',
      'testing',
    ],
    limit: 30,
  ),
  CareerTrack(
    key: 'grc',
    label: 'Compliance & Risk (GRC)',
    group: 'An ninh',
    keywords: [
      'compliance',
      'policy',
      'audit',
      'risk',
      'governance',
      'certification',
      'accredit',
    ],
    limit: 30,
  ),
  CareerTrack(
    key: 'cloud_security',
    label: 'Cloud Security',
    group: 'An ninh',
    tags: ['cloud-native', 'Security'],
    keywords: [
      'cloud',
      'access control',
      'encryption',
      'identity',
      'tenant',
      'key management',
    ],
    limit: 30,
  ),
  CareerTrack(
    key: 'sysadmin',
    label: 'Systems Administrator',
    group: 'Hạ tầng',
    keywords: [
      'operating system',
      'backup',
      'recovery',
      'account management',
      'configuration',
      'administrator',
      'file system',
    ],
    limit: 30,
  ),
  CareerTrack(
    key: 'sre',
    label: 'Site Reliability Engineer',
    group: 'Hạ tầng',
    keywords: [
      'reliability',
      'availability',
      'monitoring',
      'service level',
      'incident',
      'resilien',
      'fault',
    ],
    limit: 30,
  ),
  CareerTrack(
    key: 'dba',
    label: 'Database Administrator',
    group: 'Dữ liệu & AI',
    tags: ['Database'],
    keywords: [
      'database',
      'backup',
      'recovery',
      'replication',
      'transaction',
      'schema',
      'sql',
    ],
    limit: 30,
  ),
  CareerTrack(
    key: 'data_scientist',
    label: 'Data Scientist',
    group: 'Dữ liệu & AI',
    keywords: [
      'data analysis',
      'statistic',
      'probability',
      'entropy',
      'correlation',
      'classifier',
      'dataset',
    ],
    limit: 30,
  ),
  CareerTrack(
    key: 'mlops',
    label: 'MLOps Engineer',
    group: 'Dữ liệu & AI',
    keywords: [
      'model',
      'deployment',
      'pipeline',
      'inference',
      'training',
      'monitoring',
      'artifact',
    ],
    limit: 30,
  ),
  CareerTrack(
    key: 'tech_writer',
    label: 'Technical Writer',
    group: 'Chất lượng',
    tags: ['Process', 'Communication'],
    keywords: [
      'documentation',
      'specification',
      'conformance',
      'profile',
      'template',
      'guide',
      'requirement',
    ],
    limit: 30,
  ),
  CareerTrack(
    key: 'iot',
    label: 'IoT / Embedded',
    group: 'Sản phẩm',
    keywords: [
      'device',
      'sensor',
      'embedded',
      'iot',
      'smart card',
      'biometric',
      'firmware',
    ],
    limit: 30,
  ),
  CareerTrack(
    key: 'blockchain',
    label: 'Blockchain',
    group: 'Sản phẩm',
    keywords: [
      'blockchain',
      'ledger',
      'smart contract',
      'cryptocurrenc',
      'distributed ledger',
      'consensus',
    ],
    limit: 25,
  ),
];

/// Nhóm lộ trình theo mảng, giữ thứ tự khai báo.
Map<String, List<CareerTrack>> get careerGroups {
  final out = <String, List<CareerTrack>>{};
  for (final track in careerTracks) {
    (out[track.group] ??= <CareerTrack>[]).add(track);
  }
  return out;
}
