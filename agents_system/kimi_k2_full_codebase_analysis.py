"""
Kimi K2: Full Codebase Analysis
Comprehensive analysis of the entire RatioVita_v2 codebase, including:
- Code structure and architecture
- Documentation and notes
- Logs and configuration files
- Security and compliance implementation
- Technical debt and optimization opportunities
"""
import os
import sys
import yaml
from pathlib import Path
from datetime import datetime
from crewai import Agent, Task, Crew
from crewai_tools import FileReadTool
from config import Config

def get_credentials():
    """Get Google API credentials"""
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    
    creds = None
    token_path = Path(__file__).parent / 'token.json'
    
    if token_path.exists():
        try:
            creds = Credentials.from_authorized_user_file(str(token_path), None)
        except Exception as e:
            print(f"⚠️  Warning: Could not load credentials: {e}")
            return None
    
    if not creds:
        return None
    
    # Skip refresh to avoid scope mismatch errors
    if not creds.valid:
        pass
    
    return creds

def retrieve_codebase_content(codebase_path=None):
    """
    Comprehensive Codebase Retrieval
    Retrieves and indexes the entire RatioVita_v2 codebase for analysis.
    """
    if codebase_path is None:
        script_dir = Path(__file__).parent
        codebase_path = script_dir.parent
    
    codebase_path = Path(codebase_path)
    
    if not codebase_path.exists():
        print(f"⚠️  Warning: Codebase path does not exist: {codebase_path}")
        return None, {}
    
    print("📂 RETRIEVING RATIOVITA_V2 CODEBASE")
    print("="*80)
    
    # File extensions to analyze
    code_extensions = {
        '.py', '.swift', '.yaml', '.yml', '.json', '.md', '.txt', 
        '.plist', '.xcconfig', '.sh', '.js', '.ts', '.html', '.css',
        '.xml', '.xcodeproj', '.xcworkspace'
    }
    
    # Directories to exclude
    exclude_dirs = {
        '__pycache__', '.git', 'node_modules', 'Pods', 'DerivedData', 
        '.build', 'venv', 'env', '.venv', 'build', 'dist', '.pytest_cache',
        '.mypy_cache', 'xcuserdata', '.swiftpm', 'ARCHIVED_V1_DO_NOT_USE'
    }
    
    codebase_index = {
        'python_files': [],
        'swift_files': [],
        'config_files': [],
        'documentation': [],
        'logs': [],
        'security_related': [],
        'compliance_related': [],
        'total_files': 0,
        'total_lines': 0,
        'total_size': 0
    }
    
    file_read_tool = FileReadTool()
    
    # Walk through codebase
    for root, dirs, files in os.walk(codebase_path):
        # Filter out excluded directories
        dirs[:] = [d for d in dirs if d not in exclude_dirs]
        
        for file in files:
            file_path = Path(root) / file
            file_ext = file_path.suffix.lower()
            
            # Skip if not in our extensions
            if file_ext not in code_extensions and not any(file_path.name.endswith(ext) for ext in ['.xcodeproj', '.xcworkspace']):
                continue
            
            # Skip very large files
            try:
                file_size = file_path.stat().st_size
                if file_size > 5 * 1024 * 1024:  # Skip files larger than 5MB
                    continue
            except:
                continue
            
            try:
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    lines = content.count('\n')
                    
                file_info = {
                    'path': str(file_path.relative_to(codebase_path)),
                    'full_path': str(file_path),
                    'size': file_size,
                    'lines': lines,
                    'content_preview': content[:500],
                    'full_content': content if file_size < 100000 else content[:50000]  # Limit large files
                }
                
                # Categorize files
                if file_ext == '.py':
                    codebase_index['python_files'].append(file_info)
                elif file_ext == '.swift':
                    codebase_index['swift_files'].append(file_info)
                elif file_ext in {'.yaml', '.yml', '.json', '.plist', '.xcconfig'}:
                    codebase_index['config_files'].append(file_info)
                elif file_ext in {'.md', '.txt'}:
                    codebase_index['documentation'].append(file_info)
                    # Check if it's a log file
                    if 'log' in file_path.name.lower() or 'LOG' in file_path.name:
                        codebase_index['logs'].append(file_info)
                
                # Check for security/compliance keywords
                content_lower = content.lower()
                if any(keyword in content_lower for keyword in ['security', 'auth', 'oauth', 'privacy', 'encrypt', 'keychain', 'userdefaults', 'data protection', 'ccpa', 'gdpr']):
                    codebase_index['security_related'].append(file_info)
                if any(keyword in content_lower for keyword in ['compliance', 'ccpa', 'gdpr', 'legal', 'regulation']):
                    codebase_index['compliance_related'].append(file_info)
                
                codebase_index['total_files'] += 1
                codebase_index['total_lines'] += lines
                codebase_index['total_size'] += file_size
                
            except Exception as e:
                continue
    
    print(f"✅ Codebase indexed: {codebase_index['total_files']} files, {codebase_index['total_lines']:,} lines, {codebase_index['total_size']:,} bytes")
    print(f"   - Python files: {len(codebase_index['python_files'])}")
    print(f"   - Swift files: {len(codebase_index['swift_files'])}")
    print(f"   - Config files: {len(codebase_index['config_files'])}")
    print(f"   - Documentation: {len(codebase_index['documentation'])}")
    print(f"   - Logs: {len(codebase_index['logs'])}")
    print(f"   - Security-related: {len(codebase_index['security_related'])}")
    print(f"   - Compliance-related: {len(codebase_index['compliance_related'])}")
    print()
    
    # Format comprehensive summary for Kimi K2
    codebase_summary = f"""
================================================================================
RATIOVITA_V2 FULL CODEBASE ANALYSIS
Retrieved: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}
Total Files: {codebase_index['total_files']}
Total Lines: {codebase_index['total_lines']:,}
Total Size: {codebase_index['total_size']:,} bytes
================================================================================

PYTHON FILES ({len(codebase_index['python_files'])}):
"""
    for py_file in codebase_index['python_files'][:50]:  # Limit to first 50
        codebase_summary += f"\n📄 {py_file['path']}\n"
        codebase_summary += f"   Lines: {py_file['lines']}, Size: {py_file['size']} bytes\n"
        codebase_summary += f"   Preview: {py_file['content_preview'][:300]}...\n"
    
    codebase_summary += f"\n\nSWIFT FILES ({len(codebase_index['swift_files'])}):\n"
    for swift_file in codebase_index['swift_files'][:50]:  # Limit to first 50
        codebase_summary += f"\n📄 {swift_file['path']}\n"
        codebase_summary += f"   Lines: {swift_file['lines']}, Size: {swift_file['size']} bytes\n"
        codebase_summary += f"   Preview: {swift_file['content_preview'][:300]}...\n"
    
    codebase_summary += f"\n\nCONFIGURATION FILES ({len(codebase_index['config_files'])}):\n"
    for config_file in codebase_index['config_files'][:30]:
        codebase_summary += f"\n📄 {config_file['path']}\n"
        codebase_summary += f"   Full Content:\n{config_file['full_content'][:1000]}\n"
    
    codebase_summary += f"\n\nDOCUMENTATION & NOTES ({len(codebase_index['documentation'])}):\n"
    for doc_file in codebase_index['documentation'][:30]:
        codebase_summary += f"\n📄 {doc_file['path']}\n"
        codebase_summary += f"   Preview: {doc_file['content_preview'][:500]}...\n"
    
    codebase_summary += f"\n\nLOG FILES ({len(codebase_index['logs'])}):\n"
    for log_file in codebase_index['logs'][:20]:
        codebase_summary += f"\n📄 {log_file['path']}\n"
        codebase_summary += f"   Preview: {log_file['content_preview'][:500]}...\n"
    
    codebase_summary += f"\n\nSECURITY & COMPLIANCE RELATED FILES ({len(codebase_index['security_related'])}):\n"
    for sec_file in codebase_index['security_related']:
        codebase_summary += f"\n🔒 {sec_file['path']}\n"
        codebase_summary += f"   Full Content:\n{sec_file['full_content'][:2000]}\n"
        codebase_summary += "\n" + "="*80 + "\n"
    
    return codebase_summary, codebase_index

def kimi_k2_full_codebase_analysis():
    """
    Kimi K2 Full Codebase Analysis
    Comprehensive analysis of the entire RatioVita_v2 codebase.
    """
    print("\n" + "="*80)
    print("🔍 KIMI K2: FULL CODEBASE ANALYSIS")
    print("="*80)
    print(f"Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
    
    # Validate configuration
    try:
        Config.validate()
        print("✅ Configuration validated")
    except ValueError as e:
        print(f"❌ Configuration Error: {e}")
        return None
    
    os.environ['OPENAI_API_KEY'] = Config.OPENAI_API_KEY
    
    # Step 1: Retrieve codebase
    print("📂 RETRIEVING FULL CODEBASE...")
    codebase_summary, codebase_index = retrieve_codebase_content()
    
    if not codebase_summary:
        print("❌ Error: Failed to retrieve codebase")
        return None
    
    # Step 2: Load tools for Kimi K2
    from tools import get_gmail_tool
    
    kimi_k2_tools = []
    try:
        kimi_k2_tools.append(get_gmail_tool(agent_role="Kimi K2 - Codebase Analyst"))
    except:
        pass
    
    # Step 3: Define Kimi K2 as Codebase Analyst
    kimi_k2_agent = Agent(
        role="Codebase Analyst & Technical Architect",
        goal="Perform comprehensive analysis of the entire RatioVita_v2 codebase, including code structure, documentation, logs, security implementation, and technical debt. Provide thorough, concise, and detailed findings.",
        backstory="""You are the Codebase Analyst for the RatioVita V2 project. Your primary responsibility is to 
perform comprehensive analysis of the entire codebase, including:

1. **Code Structure & Architecture:**
   - Overall project organization
   - Module dependencies and relationships
   - Design patterns and architectural decisions
   - Code quality and maintainability

2. **Documentation & Notes:**
   - Completeness of documentation
   - Quality of code comments
   - README files and project documentation
   - Meeting notes and project logs

3. **Security & Compliance:**
   - Security implementation status
   - OAuth and authentication mechanisms
   - Data protection and privacy controls
   - CCPA/GDPR compliance implementation

4. **Technical Debt & Optimization:**
   - Code duplication
   - Outdated dependencies
   - Performance bottlenecks
   - Optimization opportunities

5. **Configuration & Infrastructure:**
   - Build configurations
   - Environment setup
   - Deployment readiness
   - CI/CD considerations

Your analysis must be thorough, concise, and actionable. Identify specific issues with file paths and line references where possible.""",
        tools=kimi_k2_tools if kimi_k2_tools else None,
        verbose=True,
        allow_delegation=False,
        max_iter=15,
        max_execution_time=900
    )
    
    # Step 4: Define Codebase Analysis Task
    analysis_task_description = f"""
**FULL CODEBASE ANALYSIS - COMPREHENSIVE REVIEW**

You must perform a thorough, concise, and detailed analysis of the entire RatioVita_v2 codebase.

**CODEBASE DATA PROVIDED:**
{codebase_summary[:150000]}

**YOUR ANALYSIS MUST COVER:**

## 1. CODE STRUCTURE & ARCHITECTURE
- Overall project organization and structure
- Module dependencies and relationships
- Design patterns used (MVC, MVVM, etc.)
- Code quality and maintainability
- Architecture strengths and weaknesses
- Recommendations for improvement

## 2. DOCUMENTATION & NOTES
- Completeness of documentation (README, code comments, etc.)
- Quality and usefulness of documentation
- Meeting notes and project logs
- Missing or outdated documentation
- Recommendations for documentation improvements

## 3. SECURITY & COMPLIANCE IMPLEMENTATION
- OAuth and authentication mechanisms
- Data protection and privacy controls
- Encryption and secure storage
- CCPA/GDPR compliance implementation
- Security vulnerabilities or concerns
- Compliance gaps
- Recommendations for security hardening

## 4. TECHNICAL DEBT & OPTIMIZATION
- Code duplication and refactoring opportunities
- Outdated dependencies or libraries
- Performance bottlenecks
- Memory leaks or resource management issues
- Optimization opportunities
- Technical debt prioritization

## 5. CONFIGURATION & INFRASTRUCTURE
- Build configurations (Xcode, Python, etc.)
- Environment setup and dependencies
- Deployment readiness
- CI/CD considerations
- Infrastructure recommendations

## 6. CODE QUALITY ASSESSMENT
- Code organization and structure
- Naming conventions and consistency
- Error handling and edge cases
- Testing coverage (if applicable)
- Best practices adherence

## 7. PROJECT HEALTH METRICS
- Overall codebase health score
- Risk factors and concerns
- Strengths and positive patterns
- Critical issues requiring immediate attention

**OUTPUT FORMAT:**

# RATIOVITA_V2 FULL CODEBASE ANALYSIS REPORT
**Date:** {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}
**Analyst:** Kimi K2 - Codebase Analyst & Technical Architect

## EXECUTIVE SUMMARY
[2-3 paragraph overview of codebase health, key findings, and critical issues]

## I. CODE STRUCTURE & ARCHITECTURE
### Overall Organization
[Assessment of project structure, organization, and architecture]

### Module Dependencies
[Analysis of dependencies and relationships between modules]

### Design Patterns
[Identification of design patterns and architectural decisions]

### Strengths & Weaknesses
[Key strengths and architectural weaknesses]

### Recommendations
[Specific recommendations for architectural improvements]

## II. DOCUMENTATION & NOTES
### Documentation Completeness
[Assessment of documentation coverage]

### Documentation Quality
[Quality assessment of existing documentation]

### Meeting Notes & Logs
[Review of project logs and meeting notes]

### Recommendations
[Documentation improvement recommendations]

## III. SECURITY & COMPLIANCE IMPLEMENTATION
### Authentication & Authorization
[Analysis of OAuth, authentication mechanisms]

### Data Protection
[Assessment of data protection and privacy controls]

### Compliance Status
[CCPA/GDPR compliance implementation status]

### Security Vulnerabilities
[Identified security concerns or vulnerabilities]

### Recommendations
[Security hardening and compliance recommendations]

## IV. TECHNICAL DEBT & OPTIMIZATION
### Code Duplication
[Identified code duplication and refactoring opportunities]

### Dependencies
[Analysis of dependencies and outdated libraries]

### Performance Issues
[Performance bottlenecks and optimization opportunities]

### Recommendations
[Prioritized technical debt and optimization recommendations]

## V. CONFIGURATION & INFRASTRUCTURE
### Build Configuration
[Analysis of build configurations and setup]

### Deployment Readiness
[Assessment of deployment readiness]

### Infrastructure Recommendations
[Infrastructure and CI/CD recommendations]

## VI. CODE QUALITY ASSESSMENT
### Organization & Structure
[Code organization and structure assessment]

### Best Practices
[Adherence to best practices and coding standards]

### Error Handling
[Error handling and edge case coverage]

### Recommendations
[Code quality improvement recommendations]

## VII. PROJECT HEALTH METRICS
### Overall Health Score
[Overall codebase health score (1-10)]

### Risk Factors
[Key risk factors and concerns]

### Strengths
[Positive patterns and strengths]

### Critical Issues
[Critical issues requiring immediate attention]

## VIII. PRIORITIZED RECOMMENDATIONS
1. [Highest priority recommendation]
2. [Second priority recommendation]
3. [Third priority recommendation]
[...]

**CRITICAL:** This analysis must be thorough, concise, and actionable. Provide specific file paths and line references where possible. Focus on actionable insights that will improve codebase quality, security, and maintainability.
"""
    
    analysis_task = Task(
        description=analysis_task_description,
        agent=kimi_k2_agent,
        expected_output="Comprehensive Full Codebase Analysis Report with detailed findings, assessments, and prioritized recommendations"
    )
    
    # Step 5: Execute Analysis
    print("🚀 EXECUTING FULL CODEBASE ANALYSIS...")
    print("="*80)
    print()
    
    try:
        crew = Crew(
            agents=[kimi_k2_agent],
            tasks=[analysis_task],
            verbose=True
        )
        
        result = crew.kickoff()
        
        print("\n" + "="*80)
        print("✅ FULL CODEBASE ANALYSIS COMPLETE")
        print("="*80)
        print(f"\nAnalysis Result:\n{result}")
        print()
        
        # Step 6: Send email alert
        print("📧 SENDING CODEBASE ANALYSIS REPORT...")
        
        try:
            from tools import get_gmail_tool
            
            gmail_tool = get_gmail_tool(agent_role="Kimi K2 - Codebase Analyst")
            
            email_body = f"""
🔍 FULL CODEBASE ANALYSIS REPORT

================================================================================
KIMI K2 FULL CODEBASE ANALYSIS
================================================================================

Date: {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}
Analyst: Kimi K2 - Codebase Analyst & Technical Architect
Scope: Entire RatioVita_v2 Codebase

Files Analyzed: {codebase_index['total_files']}
Total Lines: {codebase_index['total_lines']:,}
Total Size: {codebase_index['total_size']:,} bytes

================================================================================

FULL ANALYSIS REPORT:

{result}

================================================================================

This is an automated codebase analysis from the RatioVita V2 system.
Review the report above for detailed findings, assessments, and recommendations.

---
Kimi K2 - Codebase Analyst & Technical Architect
RatioVita V2 Multi-Agent System
"""
            
            email_result = gmail_tool(
                to="collin.m@ratiovita.com",
                subject=f"[CODEBASE ANALYSIS] Full RatioVita_v2 Analysis Report - {datetime.now().strftime('%B %d, %Y')}",
                body=email_body,
                cc="david.chen@ratiovita.com,dana.flores@ratiovita.com"
            )
            
            print(f"✅ Codebase analysis report sent via email")
            
        except Exception as e:
            print(f"⚠️  Warning: Could not send email: {e}")
        
        # Step 7: Save report
        try:
            report_file = Path(__file__).parent / f"FULL_CODEBASE_ANALYSIS_{datetime.now().strftime('%Y%m%d_%H%M%S')}.md"
            with open(report_file, 'w') as f:
                f.write(f"# RATIOVITA_V2 FULL CODEBASE ANALYSIS REPORT\n")
                f.write(f"**Date:** {datetime.now().strftime('%B %d, %Y %I:%M %p EST')}\n")
                f.write(f"**Analyst:** Kimi K2 - Codebase Analyst & Technical Architect\n\n")
                f.write(f"**Files Analyzed:** {codebase_index['total_files']}\n")
                f.write(f"**Total Lines:** {codebase_index['total_lines']:,}\n")
                f.write(f"**Total Size:** {codebase_index['total_size']:,} bytes\n\n")
                f.write("---\n\n")
                f.write(str(result))
            print(f"✅ Full report saved to: {report_file.name}")
        except Exception as e:
            print(f"⚠️  Warning: Could not save report to file: {e}")
        
        return result
        
    except Exception as e:
        print("\n" + "="*80)
        print("❌ FULL CODEBASE ANALYSIS FAILED")
        print("="*80)
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    kimi_k2_full_codebase_analysis()

