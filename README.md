## Local Installation

Clone the source code:

```bash
git clone https://github.com/dczulada/derep_builder.git
```

Install dependencies:

```bash
bundle install
```

## Getting Started

1. Modify config/derep_builder.yml to include a valid vsac_api_key.
2. Update measure-info.json to include entires for all of the expected measures. 
3. Add measure spec zip files to the measures directory. 
4. Run the Rack app:

```bash
rackup
```

Open [http://localhost:9292](http://localhost:9292) with your browser to see the result.
