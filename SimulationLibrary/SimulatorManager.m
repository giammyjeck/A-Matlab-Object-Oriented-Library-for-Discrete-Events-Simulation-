classdef SimulatorManager < handle
    % SIMULATORMANAGER Gestisce l'esecuzione della simulazione.
    %
    % Responsabile dell'avvio e del controllo del ciclo di simulazione,
    % gestendo la generazione degli scenari, l'esecuzione delle repliche e la raccolta
    % delle statistiche.
    %
    % Proprietà pubbliche:
    %   - eventList : oggetto di tipo EventsList, gestisce la lista degli eventi
    %   - scenarioGenerator : oggetto che crea e configura gli scenari di simulazione
    %   - statistics : oggetto che raccoglie e analizza le statistiche della simulazione
    %   - currentScenario : numero dello scenario attualmente in corso
    %
    % Metodi pubblici principali:
    %   - startSimulation() : avvia la simulazione per tutti gli scenari e repliche

    properties
        eventList EventsList  
        scenarioGenerator ScenarioGenerator 
        statistics Statistics
        currentScenario double {mustBeNonnegative, mustBeInteger} = 0
    end
    
    methods
        %%% Costruttore
        function obj = SimulatorManager(EventList, ScenarioGenerator, Statistics)      
            obj.eventList = EventList;
            obj.scenarioGenerator = ScenarioGenerator;
            obj.statistics = Statistics;
        end
        
        %%% STARTSIMULATION
        % Avvia la simulazione per il numero definito di scenari e di
        % replicazioni, per ogni replicazione raccoglie le statistiche e ne
        % calcola il valor medio e un intervallo di confidenza per ogni
        % scenario. 
        % Restituisce un file 'simulation_report.txt'
        %
        function startSimulation(obj)

            rng(26)
            statistiche = obj.statistics;   

            for s = 1:obj.scenarioGenerator.numScenarios
                obj.currentScenario = s;
                fprintf('--- Inizio scenario %d ---\n', s);
                
                % Genera lo scenario
                newScenarioParams = obj.scenarioGenerator.obtainScenario(s);
                % assegno i nuovi parametri alle entità
                obj.setConfig(newScenarioParams); 

                numRep = obj.scenarioGenerator.repForScenarios;
                for rep=1:numRep
                
                    fprintf('    Replicazione %d\n', rep);

                    % Ciclo principale eventi
                    time = 0;
                    while ~obj.eventList.isFinished() && time < obj.scenarioGenerator.timeHorizon
                        [event, time] = obj.eventList.getNextEvent();

                        % L'evento si gestisce richiamando l'entità target
                        event.target.handleEvent(event);                   
                            
                        % Condizione di terminazione per statistiche
                        if statistiche.stopFlag
                            break;
                        end
                    end

                    results = statistiche.collectSummary();

                    if rep == 1
                        % Prealloca con NaN e scrive header
                        numStats = length(results);
                        scenarioResults = NaN(numRep, numStats);

                        statistiche.writeHeaderSummary( ...
                            obj.scenarioGenerator.baseConfig, ...
                            rep,s,...
                            'simulation_report.txt');
                    end
                    
                    % Raccolta dati per questa rep
                    scenarioResults(rep, :) = results;

                
                    %statistiche.displayReport()
                    %obj.eventList.plotTimeline(0,300);

                    % Resetto la replicazione
                    statistiche.reset(obj.statistics.stopThreshold);
                    obj.eventList.reset();
                    obj.resetEntitiesStates();

                end %fine rep

                % Report finale per lo scenario

                % Media e intervallo di confidenza
                [meanVals, confIntervals] = statistiche.computeConfInt(scenarioResults);

                statistiche.writeScenarioSummary( ...
                    newScenarioParams, meanVals, confIntervals,'simulation_report.txt');

                fprintf('--- Fine scenario %d ---\n', s);
            end
        end
    
    end

    methods (Access = private)
        
        %%% SETCONFIG
        % Segnala alle entità coinvolte nella simulazione che la 
        % configurazioni dei loro parametri è stata aggiornata,
        % l'aggiornamento è gestito da ScenarioGenerator
        %
        function setConfig(obj, newParams)
            for i = 1:length(obj.eventList.entities)
                obj.eventList.entities{i}.setConfig(newParams);
            end
        end

        %%% RESETENTITIESSTATES
        % Su ogni entità coinvolta nella simulazione, viene chiamato il
        % metodo resetState che resetta il loro stato, in vista di una
        % nuova replicazione
        %
        function resetEntitiesStates(obj)
            for i = 1:numel(obj.eventList.entities)
                obj.eventList.entities{i}.resetState();
            end
        end

    end
end
