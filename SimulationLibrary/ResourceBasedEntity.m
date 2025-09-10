classdef ResourceBasedEntity < Entity
    % RESOURCEBASEDENTITY Classe che implementa metodi per entità di tipo
    % resourcebased
    %
    % proprietà pubbliche:
    % - capacity: struct o double, indica la capacità massima di
    % disponibile di risorsa struct('Nome Risorsa', capacitàMassima,...)
    % - busy: struct o double, indica il numerod di risorse effettivamente
    % occupare
    %
    
    properties
        capacity    
        busy        
    end
    
    methods

        %%% Costruttore
        function obj = ResourceBasedEntity(name, capacity, initialState, info)
            obj = obj@Entity(name, 'ResourceBased', initialState, info);
            obj.capacity = capacity;
            if isa(capacity, 'struct')
                obj.busy = structfun(@(x) zeros(size(x)), capacity, 'UniformOutput', false);
            else
                obj.busy = zeros(length(capacity));
            end
          
        end
   
        %%% ALLOCATE 
        % Prende una quantità e un indice di risorsa e se può alloca quella
        % quantità alla risorsa corrispondente
        %
        function success = allocate(obj, amount,index)
            if nargin == 2
                if obj.busy + amount <= obj.capacity
                    obj.busy = obj.busy + amount;
                    success = true;
                    fprintf('%s: Allocazione effettuata, occupati %d/%d\n', ...
                        obj.name, obj.busy, obj.capacity);
                else
                    success = false;
                    warning('%s: Risorsa piena!', obj.name);
                end
            elseif nargin == 3
                if isa(obj.capacity, 'vector')
                    if obj.busy(index) + amount <= obj.capacity(index)
                        obj.busy(index) = obj.busy(index) + amount;
                        success = true;
                        fprintf('%s: Allocazione effettuata, occupati %d/%d\n', ...
                            obj.name, obj.busy(index), obj.capacity(index));
                    else
                        success = false;
                        warning('%s: Risorsa piena!', obj.name);
                    end
                    
                elseif isa(obj.capacity, 'struct')

                    if obj.busy.(index) + amount <= obj.capacity.(index)
                        obj.busy.(index) = obj.busy.(index) + amount;
                        success = true;
                        fprintf('%s: Allocazione effettuata per %s, occupati %d/%d\n', ...
                            obj.name,index, obj.busy.(index), obj.capacity.(index));
                    else
                        success = false;
                        warning('%s: Risorsa piena!', obj.name);
                    end

                end
            end 
        end

        %%% RELEASE 
        % Prende in input una quantità e un indice di risorsa e dealloca la
        % quantità corrispondente
        function release(obj,amount, index)
            if nargin == 2
                if obj.busy-amount >= 0
                    obj.busy = obj.busy - amount;
                    fprintf('%s: Rilascio effettuato, occupati %d/%d\n', obj.name, obj.busy, obj.capacity);
                else
                    warning('%s: Nessuna risorsa da rilasciare!', obj.name);
                end

            elseif nargin == 3
                if obj.busy.(index) - amount >= 0
                    obj.busy.(index) = obj.busy.(index) - amount;
                    fprintf('%s: Rilascio effettuato %s, occupati %d/%d\n', obj.name, index, obj.busy.(index), obj.capacity.(index));
                else
                    warning('%s: Nessuna risorsa da rilasciare!', obj.name);
                end
            end
        end

        %%% ISAVAILABLE
        % metodo che controlla se una certa quantità può essere allocata ad
        % una risorsa, senza effettivamente allocarla
        %
        function tf = isAvailable(obj, amount,index)
            if nargin == 2
               tf = (obj.busy + amount <= obj.capacity);
            elseif nargin == 3
               tf = (obj.busy.(index) + amount <= obj.capacity.(index));
            end
        end
        
        %%% FREERESOURCE
        % metodo che libera tutta la quantità di risorsa attualmente
        % occupata
        %
        function free = freeResources(obj,index)

            if nargin == 2
               free = obj.capacity - obj.busy;
            elseif nargin == 3
               free = obj.capacity.(index) - obj.busy.(index);
            end
        end
        
        %%% RESETSTATE
        % metodo che setta a 0 le capacità disponibili per ogni tipo di
        % risorsa
        %
        function resetState(obj)
            resetState@Entity(obj);
            if isa(obj.capacity, 'struct')
                obj.busy = structfun(@(x) zeros(size(x)), obj.capacity, 'UniformOutput', false);
            else
                obj.busy = zeros(length(obj.capacity));
            end
        end

    end
end

